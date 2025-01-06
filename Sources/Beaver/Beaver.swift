import Foundation

public struct Beaver: ~Copyable, Sendable {
  var projects: AsyncRWLock<NonCopyableArray<Project>>
  public private(set) var currentProjectIndex: ProjectRef? = nil
  public var cacheDir: URL = URL.currentDirectory()
  public var optimizeMode: OptimizationMode
  var fileCache: FileCache

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
    cacheFile: URL = URL.currentDirectory().appending(path: ".beaver/cache")
  ) {
    self.projects = AsyncRWLock(NonCopyableArray(withCapacity: 3))
    self.optimizeMode = optimizeMode
    if !cacheFile.dirURL!.exists {
      try! FileManager.default.createDirectory(at: cacheFile.dirURL!, withIntermediateDirectories: true)
    }
    self.fileCache = try! FileCache(cacheFile: cacheFile)
    try! self.fileCache.selectConfiguration(mode: self.optimizeMode)
    GlobalThreadCounter.setMaxProcesses(ProcessInfo.processInfo.activeProcessorCount)
    MessageHandler.setColorEnabled(enableColor) // TODO: allow --(no-)color (if not specified, pass nil)

    // TODO: if script file changed, or any of the requires; rebuild
    // At the end of execution, save all of the files the script requires into cache and retrieve them the next time Beaver is used
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

  public func build(targetName: String) async throws {
    guard let currentProject = self.currentProjectIndex else {
      throw BuildError.noDefaultTarget
    }
    guard let index = await self.targetIndex(name: targetName, project: currentProject) else {
      throw BuildError.noTarget(named: targetName)
    }
    try await self.build(TargetRef(target: index, project: self.currentProjectIndex!))
  }

  public func build(_ targetRef: TargetRef) async throws {
    try await self.withTarget(targetRef) { (target: borrowing any Target) async throws in
      try await MessageHandler.withIndicators {
        let dependencyGraph = try await DependencyGraph(startingFrom: targetRef, context: self)
        let builder = try await DependencyBuilder(dependencyGraph, context: self)
        try await builder.run(context: self)
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
