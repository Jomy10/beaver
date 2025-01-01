public struct Beaver: ~Copyable, Sendable {
  var projects: AsyncRWLock<NonCopyableArray<Project>>
  public private(set) var currentProjectIndex: ProjectRef? = nil

  public init() {
    self.projects = AsyncRWLock(NonCopyableArray(withCapacity: 3))
  }

  public mutating func addProject(_ project: consuming Project) async {
    let rcProj = Rc(project)
    await self.projects.write { projects in
      projects.append(rcProj.take()!)
      self.currentProjectIndex = projects.count - 1
    }
  }

  public func getProjectRef(byName name: String) async -> Int? {
    await self.projects.read { $0.firstIndex(where: { proj in proj.name == name }) }
  }

  enum BeaverError: Error {
    case noDefaultProject
    case noProject(named: String)
  }

  public mutating func withCurrentProject<Result>(_ cb: @Sendable (inout Project) async throws -> Result) async throws -> Result {
    try await self.projects.write { projects in
      if let currentProjectIndex = self.currentProjectIndex {
        return try await projects.mutatingElement(currentProjectIndex, cb)
      } else {
        throw BeaverError.noDefaultProject
      }
    }
  }

  public func withCurrentProject<Result>(_ cb: @Sendable (borrowing Project) async throws -> Result) async throws -> Result {
    try await self.projects.read { projects in
      if let currentProjectIndex = self.currentProjectIndex {
        return try await projects.withElement(currentProjectIndex, cb)
      } else {
        throw BeaverError.noDefaultProject
      }
    }
  }

  public func withProject<Result>(named projectName: String, _ cb: @Sendable (borrowing Project) async throws -> Result) async throws -> Result {
    try await self.projects.read { projects in
      guard let index = projects.firstIndex(where: { project in project.name == projectName }) else {
        throw BeaverError.noProject(named: projectName)
      }
      return try await projects.withElement(index, cb)
    }
  }

  public func withProject<Result>(index: ProjectRef, _ cb: @Sendable (borrowing Project) async throws -> Result) async throws -> Result {
    try await self.projects.read { projects in
      return try await projects.withElement(index, cb)
    }
  }

  public func withLibrary<Result>(_ libraryRef: LibraryRef, _ cb: @Sendable (borrowing any Library) async throws -> Result) async throws -> Result {
    return try await self.projects.read { (projects: borrowing NonCopyableArray<Project>) async throws -> Result in
      return try await projects.withElement(libraryRef.project) { (project: borrowing Project) async throws -> Result in
        return try await project.withLibrary(named: libraryRef.name, cb)
      }
    }
  }

  public enum ParsingError: Error {
    case unexpectedNoComponents
    case malformed(String)
  }

  public func build(_ targetName: String) async throws {
    let components = targetName.split(separator: ":")
    let projectIndex: ProjectRef
    let selectedTargetName: String
    switch (components.count) {
      case 0:
        throw ParsingError.unexpectedNoComponents
      case 1:
        projectIndex = self.currentProjectIndex!
        selectedTargetName = targetName
      case 2:
        guard let index = await self.getProjectRef(byName: String(components[0])) else {
          throw BeaverError.noProject(named: String(components[0]))
        }
        projectIndex = index
        selectedTargetName = String(components[1])
      default:
        throw ParsingError.malformed(targetName)
    }

    try await self.withProject(index: projectIndex) { (project: borrowing Project) async throws in
      try await project.withTarget(named: selectedTargetName) { (target: borrowing any Target) async throws in
        if target.useDependencyGraph {
          await MessageHandler.enableIndicators()
          let dependencyGraph = try await DependencyGraph(startingFromTarget: selectedTargetName, inProject: projectIndex, context: self)
          try await self.build(dependencyGraph: dependencyGraph)
          await MessageHandler.closeIndicators()
        } else {
          try await target.build(baseDir: project.baseDir, buildDir: project.buildDir, context: self)
        }
      }
    }
  }

  private func build(dependencyGraph: consuming DependencyGraph) async throws {
    let builder = DependencyBuilder(dependencyGraph)
    try await builder.run(context: self)
  }

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
