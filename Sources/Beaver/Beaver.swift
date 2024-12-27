public struct Beaver: ~Copyable, Sendable {
  var projects: AsyncRWLock<NonCopyableArray<Project>>
  var currentProjectIndex: ProjectRef? = nil

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

  public func withLibrary<Result>(_ libraryRef: LibraryRef, _ cb: @Sendable (borrowing any Library) async throws -> Result) async throws -> Result {
    return try await self.projects.read { (projects: borrowing NonCopyableArray<Project>) async throws -> Result in
      return try await projects.withElement(libraryRef.project) { (project: borrowing Project) async throws -> Result in
        return try await project.withLibrary(named: libraryRef.name, cb)
      }
    }
  }

  // call in init()
  func check() {}
}
