import Foundation

public struct Beaver: ~Copyable, Sendable {
  var projects: AsyncRWLock<NonCopyableArray<Project>>
  public private(set) var currentProjectIndex: ProjectRef? = nil
  public var cacheDir: URL = URL.currentDirectory()
  public var optimizeMode: OptimizationMode
  var cacheFile: URL
  var fileCache: FileCache?

  //public struct Settings: ~Copyable, Sendable {
  //  /// The amount of c objects to compile per thread.
  //  /// e.g. when this variable is 10 and there are 20 sources, this means 2 threads will be
  //  /// spawned to compile the C target
  //  var cObjectsPerThread: Int = 10
  //}

  // TODO: handle error
  public init(
    enableColor: Bool? = nil,
    optimizeMode: OptimizationMode = .debug,
    cacheFile: URL = URL.currentDirectory().appending(path: ".beaver").appending(path: "cache")
  ) throws {
    self.projects = AsyncRWLock(NonCopyableArray(withCapacity: 3))
    self.optimizeMode = optimizeMode
    self.cacheFile = cacheFile
    self.fileCache = nil
    let cacheFileBaseURL = cacheFile.dirURL!
    if !cacheFileBaseURL.exists {
      try FileManager.default.createDirectory(at: cacheFileBaseURL, withIntermediateDirectories: true)
    }
    //try! self.fileCache.selectConfiguration(mode: self.optimizeMode)
    GlobalThreadCounter.setMaxProcesses(ProcessInfo.processInfo.activeProcessorCount)
    MessageHandler.setColorEnabled(enableColor) // TODO: allow --(no-)color (if not specified, pass nil)

    // TODO: if script file changed, or any of the requires; rebuild
    // At the end of execution, save all of the files the script requires into cache and retrieve them the next time Beaver is used
  }

  /// Should be called after all configuration has been set and targets have been declared
  public mutating func finalize() throws {
    self.fileCache = try FileCache(cacheFile: self.cacheFile)
    try self.fileCache?.selectConfiguration(mode: self.optimizeMode)
  }

  @discardableResult
  public mutating func addProject(_ project: consuming Project) async -> ProjectRef {
    var project: Project? = project
    return await self.projects.write { projects in
      let id = projects.count
      var project = project.take()!
      project.id = id
      projects.append(project)
      self.currentProjectIndex = id
      return id
    }
  }

  enum BuildError: Error {
    case noTarget(named: String)
    case noDefaultTarget
  }

  public func build(targetName: String, artifact: ArtifactType? = nil) async throws {
    try await self.build(try await self.evaluateTarget(targetName: targetName), artifact: artifact)
  }

  public func build(_ targetRef: TargetRef, artifact: ArtifactType? = nil) async throws {
    try await self.withTarget(targetRef) { (target: borrowing any Target) async throws in
      try await MessageHandler.withIndicators {
        let dependencyGraph = try await DependencyGraph(startingFrom: targetRef, artifact: artifact, context: self)
        let builder = try await DependencyBuilder(dependencyGraph, context: self)
        try await builder.run(context: self)
      }
    }
  }

  public func run(targetName: String, args: [String] = []) async throws {
    try await self.run(try await self.evaluateTarget(targetName: targetName), args: args)
  }

  public func run(_ targetRef: TargetRef, args: [String] = []) async throws {
    try await self.build(targetRef, artifact: .executable(.executable))
    let executableURL = try await self.withProjectAndExecutable(targetRef) { (project: borrowing Project, executable: borrowing any Executable) async throws in
      try await executable.artifactURL(projectBuildDir: project.buildDir, .executable)
    }
    try await Tools.exec(executableURL, args)
  }

  public func clean(projectName: String) async throws {
    try await self.clean(await self.projectRef(name: projectName))
  }

  public func clean(_ projectRef: ProjectRef? = nil) async throws {
    if let projectRef = projectRef {
      try await self.withProject(projectRef) { (project: borrowing Project) in
        MessageHandler.print("Cleaning \(project.name)...")
        try await project.clean(context: self)
      }
    } else {
      MessageHandler.print("Cleaning all targets...")
      try await self.loopProjects { (project: borrowing Project) in
        try await project.clean(context: self)
      }
    }
  }

  // call in init()
  func check() {}
}

public enum OptimizationMode: String, Sendable {
  case debug
  case release
  // TODO: case custom(String)
}
