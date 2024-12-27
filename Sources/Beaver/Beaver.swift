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
    switch (components.count) {
      case 0:
        throw ParsingError.unexpectedNoComponents
      case 1:
        try await self.withCurrentProject { (proj: borrowing Project) async throws -> Void in
          try await proj.withTarget(named: targetName) { (target: borrowing any Target) async throws -> Void in
            try await target.build(baseDir: proj.baseDir, buildDir: proj.buildDir, context: self)
          }
        }
      case 2:
        try await self.withProject(named: String(components[0])) { (proj: borrowing Project) async throws -> Void in
          try await proj.withTarget(named: targetName) { (target: borrowing any Target) async throws -> Void in
            try await target.build(baseDir: proj.baseDir, buildDir: proj.buildDir, context: self)
          }
        }
      default:
        throw ParsingError.malformed(targetName)
    }
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
