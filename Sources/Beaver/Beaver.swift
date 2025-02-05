import Foundation
import Utils
import Atomics

// TODO: global build dir and store cache db there

public struct Beaver: ~Copyable, Sendable {
  var projects: AsyncRWLock<NonCopyableArray<AnyProject>>
  private var currentProjectIndexAtomic: ManagedAtomic<ProjectRef> = ManagedAtomic(-1)
  public var currentProjectIndex: ProjectRef? {
    get {
      let idx = self.currentProjectIndexAtomic.load(ordering: .sequentiallyConsistent)
      if idx == -1 { return nil }
      return idx
    }
  }

  public var optimizeMode: OptimizationMode

  var buildDir: URL

  var cacheFile: URL
  var fileCache: FileCache?

  var commands: Commands

  var config: BeaverConfig

  private func setCurrentProjectIndex(_ idx: ProjectRef) async {
    while true {
      let val = self.currentProjectIndexAtomic.load(ordering: .relaxed)
      let (done, _) = self.currentProjectIndexAtomic.weakCompareExchange(expected: val, desired: idx, ordering: .sequentiallyConsistent)
      if (done) { break }
      await Task.yield()
    }
  }

  public enum InitializationError: Error {
    case fileCacheAlreadyInitialized
  }

  public init(
    enableColor: Bool? = nil,
    optimizeMode: OptimizationMode = .debug
    //cacheFile: URL = URL.currentDirectory().appending(path: ".beaver").appending(path: "cache")
  ) throws {
    self.projects = AsyncRWLock(NonCopyableArray(withCapacity: 3))
    self.optimizeMode = optimizeMode
    self.buildDir = URL.currentDirectory().absoluteURL.appending(path: "build")
    self.cacheFile = self.buildDir.appending(path: "cache")
    //self.cacheFile = cacheFile
    self.fileCache = nil
    self.commands = Commands()
    self.config = BeaverConfig()

    MessageHandler.setColorEnabled(enableColor)

    // TODO: if script file changed, or any of the requires; rebuild
    // At the end of execution, save all of the files the script requires into cache and retrieve them the next time Beaver is used
  }

  /// Should be called after all configuration has been set and targets have been declared
  public mutating func finalize() async throws {
    if self.fileCache == nil {
      try self.initializeCache()
    }

    // Check if targets have changed and if that should cause a rebuild / relink.
    // Stores new targets in the database and removes removed ones
    try await self.fileCache?.checkTargets(context: self)
  }

  private mutating func initializeCache() throws {
    if self.fileCache != nil {
      throw InitializationError.fileCacheAlreadyInitialized
    }
    try FileManager.default.createDirectoryIfNotExists(at: self.buildDir)
    self.fileCache = try FileCache(cacheFile: self.cacheFile)
    try self.fileCache?.selectConfiguration(mode: self.optimizeMode)
  }

  public mutating func setBuildDir(_ dir: URL) throws {
    if self.fileCache != nil {
      throw InitializationError.fileCacheAlreadyInitialized
    }
    self.buildDir = dir
    self.cacheFile = dir.appending(path: "cache")
    try self.initializeCache()
  }

  public mutating func requireBuildDir() throws {
    if self.fileCache == nil {
      try self.initializeCache()
    }
  }

  public func buildDir(for name: String) -> URL {
    self.buildDir.appending(path: name).appending(path: self.optimizeMode.description)
  }

  //public mutating func setCacheFile(_ file: URL) throws(InitializationError) {
  //  if self.fileCache != nil {
  //    throw .fileCacheAlreadyInitialized
  //  }
  //  self.cacheFile = file
  //}

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
  }

  public func buildCurrentProject() async throws {
    try await self.withCurrentProject { (project: borrowing AnyProject) in
      try await project.build(context: self)
    }
  }

  @inlinable
  public func build(targetName: String, artifact: ArtifactType? = nil) async throws {
    try await self.build(try await self.evaluateTarget(targetName: targetName), artifact: artifact)
  }

  public func build(_ targetRef: TargetRef, artifact: ArtifactType? = nil) async throws {
    let builder = try await TargetBuilder(target: targetRef, artifact: artifact, context: self)
    await builder.build(context: self)
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
    try await self.build(targetRef, artifact: .executable(.executable))
    try await self.withProjectAndExecutable(targetRef) { (project: borrowing AnyProject, executable: borrowing AnyExecutable) in
      try await executable.run(projectBuildDir: project.buildDir, args: args)
    }
  }

  @inlinable
  public func clean(projectName: String) async throws {
    guard let projectRef = await self.projectRef(name: projectName) else {
      throw ProjectAccessError.noProject(named: projectName)
    }
    try await self.clean(projectRef)
  }

  public func clean(_ projectRef: ProjectRef? = nil) async throws {
    if let projectRef = projectRef {
      try await self.withProject(projectRef) { (project: borrowing AnyProject) in
        MessageHandler.print("Cleaning \(project.name)...")
        try await project.clean(context: self)
      }
    } else {
      try await self.withCurrentProject { (project: borrowing AnyProject) in
        MessageHandler.print("Cleaning all targets of \(project.name)...")
        try await project.clean(context: self)
      }
    }
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

  public func fileChanged(_ file: URL, context: String) throws -> Bool {
    return try self.fileCache!.fileChanged(file, context: context)
  }

  public func cacheSetVar(context: String, value: String) throws {
    try self.cacheSetVar(context: context, value: .string(value))
  }

  public func cacheSetVar(context: String, value: Int) throws {
    try self.cacheSetVar(context: context, value: .int(value))
  }

  public func cacheSetVar(context: String, value: Double) throws {
    try self.cacheSetVar(context: context, value: .double(value))
  }

  public func cacheSetVar(context: String, value: Bool) throws {
    try self.cacheSetVar(context: context, value: .bool(value))
  }

  public func cacheSetVar(context: String, value: CacheVarVal?) throws {
    try self.fileCache!.cacheSetVar(context: context, value: value)
  }

  public func cacheGetVar(context: String) throws -> CacheVarVal? {
    try self.fileCache!.cacheGetVar(context: context)
  }

  // call in init()
  //func check() {}
}
