import Foundation
import Utils
import Atomics

public struct Beaver: ~Copyable, Sendable {
  var projects: AsyncRWLock<NonCopyableArray<AnyProject>>

  private var __currentProjectIndex: ManagedAtomic<ProjectRef> = ManagedAtomic(-1)
  public var currentProjectIndex: ProjectRef? {
    get {
      let idx = self.__currentProjectIndex.load(ordering: .sequentiallyConsistent)
      if idx == -1 { return nil }
      return idx
    }
  }

  public var optimizeMode: OptimizationMode

  var buildDir: URL
  var buildBackendFile: URL
  var ninja: NinjaRunner?
  var cache: Cache?

  var commands: Commands

  private func setCurrentProjectIndex(_ idx: ProjectRef) async {
    while true {
      let val = self.__currentProjectIndex.load(ordering: .relaxed)
      let (done, _) = self.__currentProjectIndex.weakCompareExchange(expected: val, desired: idx, ordering: .sequentiallyConsistent)
      if (done) { break }
      await Task.yield()
    }
  }

  public init(
    enableColor: Bool? = nil,
    optimizeMode: OptimizationMode = .debug
  ) throws {
    self.projects = AsyncRWLock(NonCopyableArray(withCapacity: 3))
    self.optimizeMode = optimizeMode
    self.buildDir = URL.currentDirectory().appending(path: "build")
//    self.cacheFile = self.buildDir.appending(path: "cache")
//    self.cache = nil
    self.commands = Commands()
    self.buildBackendFile = self.buildDir.appending(path: "build.\(optimizeMode).ninja")

    if let enableColor = enableColor {
      Tools.enableColor = enableColor
    }
  }

  public enum InitializationError: Error {
    case fileCacheAlreadyInitialized
  }

  /// Should be called after all configuration has been set and targets have been declared
  public mutating func finalize() async throws {
    try FileManager.default.createDirectoryIfNotExists(at: self.buildDir, withIntermediateDirectories: true)

    var stmts = BuildBackendBuilder()
    stmts.add("builddir = \(self.buildDir.ninjaPath)")
    var languages = Set<Language>()
    var hasCMake = false

    _ = await self.loopProjects { (project: borrowing AnyProject) in
      switch (project) {
        case .cmake(_):
          hasCMake = true
        case .beaver(let proj):
          _ = await proj.loopTargets { (target: borrowing AnyTarget) in
            languages.insert(target.language)
          }
      }
    }

    try stmts.addRules(forLanguages: languages)
    if hasCMake {
      stmts.addNinjaRule()
    }

    try await self.loopProjects { project in
      stmts.join(try await project.buildStatements(context: self))
    }
    let fileContents: String = stmts.finalize()
    try fileContents.write(to: self.buildBackendFile, atomically: true, encoding: .utf8)
    self.ninja = try NinjaRunner(buildFile: self.buildBackendFile.path)
    if self.shouldCleanArtifacts {
      try self.cleanArtifacts(keepingCurrentConfiguration: true)
    }

    try self.initializeCache()
  }

  var shouldCleanArtifacts = false

  private mutating func initializeCache() throws {
    if self.cache != nil {
      return
      //throw InitializationError.fileCacheAlreadyInitialized
    }

    try FileManager.default.createDirectoryIfNotExists(at: self.buildDir, withIntermediateDirectories: true)
    self.cache = try Cache(self.buildDir.appending(path: "cache"), buildId: BeaverConstants.buildId, clean: &self.shouldCleanArtifacts)
    try self.cache!.selectConfiguration(mode: self.optimizeMode)
  }

  //private mutating func initializeCache() throws {
  //  if self.cache != nil {
  //    throw InitializationError.fileCacheAlreadyInitialized
  //  }

  //  try FileManager.default.createDirectoryIfNotExists(at: self.buildDir)
  //  self.cache = try Cache(cacheFile: self.cacheFile, globalConfig: Cache.GlobalConfig(buildId: BeaverConstants.buildId))
  //  try self.cache!.selectConfiguration(mode: self.optimizeMode)
  //}

  public mutating func setBuildDir(_ dir: URL) throws {
    //if self.fileCache != nil {
    //  throw InitializationError.fileCacheAlreadyInitialized
    //}
    self.buildDir = dir
    //self.cacheFile = dir.appending(path: "cache")
    self.buildBackendFile = self.buildDir.appending(path: "build.\(optimizeMode).ninja")
    //try self.initializeCache()
  }

  public mutating func requireBuildDir() throws {
    if self.cache == nil {
      try self.initializeCache()
    }
  }

  public func buildDir(for name: String) -> URL {
    self.buildDir.appending(path: name).appending(path: self.optimizeMode.description)
  }

  @discardableResult
  public mutating func addProject(_ project: consuming AnyProject) async -> ProjectRef {
    var project: AnyProject? = project
    return await self.projects.write { (projects: inout NonCopyableArray<AnyProject>) in
      let id = projects.count
      var project = project.take()!
      project.id = id
      projects.append(project)
      await self.setCurrentProjectIndex(id)
      return id
    }
  }

  enum BuildError: Error {
    case noTarget(named: String)
    case noDefaultTarget
    /// Any error happened during compilation/linking
    case buildError
  }

  public func buildCurrentProject() async throws {
    try await self.withCurrentProject { (project: borrowing AnyProject) in
      //try await project.build(context: self)
      try await self.ninja!.build(targets: project.name)
    }
  }

  // TODO: build(many targets)

  @inlinable
  public func build(targetName: String, artifact: ArtifactType? = nil) async throws {
    try await self.build(try await self.evaluateTarget(targetName: targetName), artifact: artifact)
  }

  /// Returns true if any occured during build
  public func build(_ targetRef: TargetRef, artifact: ArtifactType? = nil) async throws {
    try await self.withProjectAndTarget(targetRef) { (project: borrowing AnyProject, target: borrowing AnyTarget) in
      switch (project) {
        case .cmake(let project):
          try await project.build(target, context: self)
        default:
          if let artifact {
            try await self.ninja!.build(targets: target.ninjaTarget(inProject: project, artifact: artifact))
          //  try await target.build(artifact: artifact, projectBaseDir: project.baseDir, projectBuildDir: self.buildDir(for: project.name), context: self)
          } else {
            try await self.ninja!.build(targets: target.ninjaTarget(inProject: project))
          //  try await target.build(projectBaseDir: project.baseDir, projectBuildDir: self.buildDir(for: project.name), context: self)
          }
      }
    }
    //let builder = try await TargetBuilder(target: targetRef, artifact: artifact, context: self)
    //if (await builder.build(context: self)) {
    //  throw BuildError.buildError
    //}
  }

  enum RunError: Error {
    case noExecutables
    /// There is more than one executable present
    case moreExecutables
  }

  public func run(args: [String] = []) async throws {
    try await self.withCurrentProject { (project: borrowing AnyProject) in
      try await project.run(args: args, context: self)
    }
  }

  @inlinable
  public func run(targetName: String, args: [String] = []) async throws {
    try await self.run(try await self.evaluateTarget(targetName: targetName), args: args)
  }

  public func run(_ targetRef: TargetRef, args: [String] = []) async throws {
    //try await self.build(targetRef, artifact: .executable(.executable))
    try await self.withProjectAndExecutable(targetRef) { (project: borrowing AnyProject, executable: borrowing AnyExecutable) in
      try await self.ninja!.build(targets: executable.ninjaTarget(inProject: project, artifact: .executable))
      try await executable.run(projectBuildDir: project.buildDir(self), args: args)
    }
  }

  public func clean() throws {
    //try self.cleanArtifacts()
    let debugBuildFile = self.buildDir.appending(path: "build.debug.ninja")
        let releaseBuildFile = self.buildDir.appending(path: "build.release.ninja")

        if FileManager.default.exists(at: debugBuildFile) {
          try NinjaRunner(buildFile: debugBuildFile.path(percentEncoded: false)).runSync(tool: "clean")
          //if (!keepingCurrentConfiguration || (keepingCurrentConfiguration && self.optimizeMode != .debug)) {
            try FileManager.default.removeItem(at: debugBuildFile)
          //}
        }

        if FileManager.default.exists(at: releaseBuildFile) {
          try NinjaRunner(buildFile: releaseBuildFile.path(percentEncoded: false)).runSync(tool: "clean")
          //if (!keepingCurrentConfiguration || (keepingCurrentConfiguration && self.optimizeMode != .release)) {
            try FileManager.default.removeItem(at: releaseBuildFile)
          //}
        }
  }

  public func cleanArtifacts(keepingCurrentConfiguration: Bool = false) throws {
    print("Project should be automatically cleaned, but this is currently not supported. Consider doing a manual clean")
    //try self.ninja!.runSync(tool: "clean")

    //let debugBuildFile = self.buildDir.appending(path: "build.debug.ninja")
    //let releaseBuildFile = self.buildDir.appending(path: "build.release.ninja")

    //if FileManager.default.exists(at: debugBuildFile) {
    //  try NinjaRunner(buildFile: debugBuildFile.path(percentEncoded: false)).runSync(tool: "clean")
    //  if (!keepingCurrentConfiguration || (keepingCurrentConfiguration && self.optimizeMode != .debug)) {
    //    try FileManager.default.removeItem(at: debugBuildFile)
    //  }
    //}

    //if FileManager.default.exists(at: releaseBuildFile) {
    //  try NinjaRunner(buildFile: releaseBuildFile.path(percentEncoded: false)).runSync(tool: "clean")
    //  if (!keepingCurrentConfiguration || (keepingCurrentConfiguration && self.optimizeMode != .release)) {
    //    try FileManager.default.removeItem(at: releaseBuildFile)
    //  }
    //}

    // TODO: clean CMake projects!
  }

  public mutating func addCommand(
    _ name: String,
    overwrite: Bool = false,
    _ execute: @escaping Commands.Command
  ) async throws {
    if self.currentProjectIndex != nil {
      try await self.withCurrentProject { (project: inout AnyProject) async throws -> Void in
        try await project.asCommandCapable { (project: inout AnyCommandCapableProjectRef) in
          try await project.addCommand(name, overwrite: overwrite, execute)
        }
      }
    } else {
      try await self.commands.addCommand(name: name, overwrite: overwrite, execute: execute)
    }
  }

  public func call(_ commandName: String) async throws {
    if self.currentProjectIndex != nil {
      if commandName.contains(":") {
        let commandParts = commandName.split(separator: ":", maxSplits: 1)
        let project = String(commandParts[0])
        let command = String(commandParts[1])
        guard let projectIndex = await self.projectIndex(name: project) else {
          throw ProjectAccessError.noProject(named: project)
        }
        try await self.withProject(projectIndex) { (project: borrowing AnyProject) async throws -> Void in
          try await project.asCommandCapable { (project: borrowing AnyCommandCapableProjectRef) in
            if await project.hasCommand(command) {
              try await project.call(commandName, context: self)
            } else {
              try await self.commands.call(commandName, context: self)
            }
          }
        }
      } else {
        try await self.withCurrentProject { (project: borrowing AnyProject) async throws -> () in
          try await project.asCommandCapable { (project: borrowing AnyCommandCapableProjectRef) in
            if await project.hasCommand(commandName) {
              try await project.call(commandName, context: self)
            } else {
              try await self.commands.call(commandName, context: self)
            }
          }
        }
      }
    } else {
      try await self.commands.call(commandName, context: self)
    }
  }

  public func callDefault() async throws {
    if self.currentProjectIndex != nil {
      try await self.withCurrentProject { (project: borrowing AnyProject) in
        try await project.asCommandCapable { (proj: borrowing AnyCommandCapableProjectRef) in
          if await project.hasCommands() {
            try await project.callDefault(context: self)
          } else {
            try await self.commands.callDefault(context: self)
          }
        }
      }
    } else {
      try await self.commands.callDefault(context: self)
    }
  }

  public func isOverwritten(_ commandName: String) async throws -> Bool {
    if self.currentProjectIndex != nil {
      try await self.withCurrentProject { (project: borrowing AnyProject) in
        try await project.asCommandCapable { (proj: borrowing AnyCommandCapableProjectRef) in
          if await project.hasCommand(commandName) {
            await project.isOverwritten(commandName)
          } else {
            await self.commands.overwrites.contains(commandName)
          }
        }
      }
    } else {
      await self.commands.overwrites.contains(commandName)
    }
  }

  // Custom Cache //
  public mutating func fileChanged(_ file: URL, context: String) throws -> Bool {
    try self.requireBuildDir()
    return try self.cache!.fileChanged(file: file, context: context)
  }

  public mutating func cacheSetVar(context: String, value: String) throws {
    try self.requireBuildDir()
    try self.cacheSetVar(context: context, value: .string(value))
  }

  public mutating func cacheSetVar(context: String, value: Int) throws {
    try self.requireBuildDir()
    try self.cacheSetVar(context: context, value: .int(value))
  }

  public mutating func cacheSetVar(context: String, value: Double) throws {
    try self.requireBuildDir()
    try self.cacheSetVar(context: context, value: .double(value))
  }

  public mutating func cacheSetVar(context: String, value: Bool) throws {
    try self.requireBuildDir()
    try self.cacheSetVar(context: context, value: .bool(value))
  }

  public mutating func cacheSetVar(context: String, value: CacheVarVal) throws {
    try self.requireBuildDir()
    try self.cache!.setVar(name: context, value: value)
  }

  public mutating func cacheGetVar(context: String) throws -> CacheVarVal {
    try self.requireBuildDir()
    return try self.cache!.getVar(name: context)
  }

  //public func configChanged(context: String) throws -> Bool {
  //  try self.cache!.configChanged(context: context)
  //}
}
