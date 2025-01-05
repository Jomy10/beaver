import Foundation

public struct Beaver: ~Copyable, Sendable {
  var projects: AsyncRWLock<NonCopyableArray<Project>>
  public private(set) var currentProjectIndex: ProjectRef? = nil
  public var cacheDir: URL = URL.currentDirectory()
  public var settings: Settings
  public var optimizeMode: OptimizationMode

  public struct Settings: ~Copyable, Sendable {
    /// The amount of c objects to compile per thread.
    /// e.g. when this variable is 10 and there are 20 sources, this means 2 threads will be
    /// spawned to compile the C target
    var cObjectsPerThread: Int = 10
  }

  public init(enableColor: Bool? = nil, optimizeMode: OptimizationMode = .debug) {
    self.projects = AsyncRWLock(NonCopyableArray(withCapacity: 3))
    self.settings = Settings()
    self.optimizeMode = optimizeMode
    GlobalThreadCounter.setMaxProcesses(ProcessInfo.processInfo.activeProcessorCount)
    MessageHandler.setColorEnabled(enableColor) // TODO: allow --(no-)color (if not specified, pass nil)
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

  @available(*, deprecated, message: "Use `projectRef(name:)`")
  public func getProjectRef(byName name: String) async -> Int? {
    await self.projects.read { $0.firstIndex(where: { proj in proj.name == name }) }
  }

  //public mutating func withCurrentProject<Result>(_ cb: @Sendable (inout Project) async throws -> Result) async throws -> Result {
  //  try await self.projects.write { projects in
  //    if let currentProjectIndex = self.currentProjectIndex {
  //      return try await projects.mutatingElement(currentProjectIndex, cb)
  //    } else {
  //      throw BeaverError.noDefaultProject
  //    }
  //  }
  //}

  //public func withCurrentProject<Result>(_ cb: @Sendable (borrowing Project) async throws -> Result) async throws -> Result {
  //  try await self.projects.read { projects in
  //    if let currentProjectIndex = self.currentProjectIndex {
  //      return try await projects.withElement(currentProjectIndex, cb)
  //    } else {
  //      throw BeaverError.noDefaultProject
  //    }
  //  }
  //}

  //public func withProject<Result>(named projectName: String, _ cb: @Sendable (borrowing Project) async throws -> Result) async throws -> Result {
  //  try await self.projects.read { projects in
  //    guard let index = projects.firstIndex(where: { project in project.name == projectName }) else {
  //      throw BeaverError.noProject(named: projectName)
  //    }
  //    return try await projects.withElement(index, cb)
  //  }
  //}

  @available(*, deprecated)
  public func withProject<Result>(index: ProjectRef, _ cb: @Sendable (borrowing Project) async throws -> Result) async throws -> Result {
    try await self.projects.read { projects in
      return try await projects.withElement(index, cb)
    }
  }

  @available(*, deprecated)
  public func withLibrary<Result>(_ libraryRef: LibraryRef, _ cb: @Sendable (borrowing any Library) async throws -> Result) async throws -> Result {
    return try await self.projects.read { (projects: borrowing NonCopyableArray<Project>) async throws -> Result in
      return try await projects.withElement(libraryRef.project) { (project: borrowing Project) async throws -> Result in
        return try await project.withLibrary(named: libraryRef.name, cb)
      }
    }
  }

  @available(*, deprecated)
  public func withProjectAndLibrary<Result>(_ libraryRef: LibraryRef, _ cb: @Sendable (borrowing Project, borrowing any Library) async throws -> Result) async throws -> Result {
    return try await self.withProject(libraryRef.project) { (project: borrowing Project) in
      return try await project.withLibrary(named: libraryRef.name) { (lib: borrowing any Library) in
        return try await cb(project, lib)
      }
    }
  }

  //public func withTarget<Result>(_ target: TargetRef, _ cb: @Sendable (borrowing any Target) async throws -> Result) async throws -> Result {
  //  return try await self.withProject(index: target.project) { (project: borrowing Project) async throws -> Result in
  //    return try await project.withTarget(named: target.name, cb)
  //  }
  //}

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
      await MessageHandler.enableIndicators()
      //let dependencyGraph = try await DependencyGraph(startingFromTarget: selectedTargetName, inProject: targetRef.project, context: self)
      let dependencyGraph = try await DependencyGraph(startingFrom: targetRef, context: self)
      try await self.build(dependencyGraph: dependencyGraph)
      await MessageHandler.closeIndicators()
    }
  }

  private func build(dependencyGraph: consuming DependencyGraph) async throws {
    let builder = try await DependencyBuilder(dependencyGraph, context: self)
    try await builder.run(context: self)
  }

  @available(*, deprecated, message: "Use Dependency instead")
  public func build(_ library: LibraryRef) async throws {
    try await self.withProject(index: library.project) { (proj: borrowing Project) async throws -> Void in
      try await proj.withLibrary(named: library.name) { (library: borrowing any Library) async throws -> Void in
        try await library.build(baseDir: proj.baseDir, buildDir: proj.buildDir, context: self)
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
