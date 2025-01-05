extension Beaver {
  // Access project //
  enum ProjectAccessError: Error {
    case noDefaultProject
    case noProject(named: String)
  }

  public func withProject<Result>(_ index: ProjectRef, _ cb: (borrowing Project) async throws -> Result) async rethrows -> Result {
    try await self.projects.read { projects in
      try await cb(projects.buffer[index])
    }
  }

  public mutating func withProject<Result>(_ index: ProjectRef, _ cb: (inout Project) async throws -> Result) async rethrows -> Result {
    try await self.projects.write { projects in
      try await cb(&projects.buffer[index])
    }
  }

  public func withProject<Result>(named projectName: String, _ cb: (borrowing Project) async throws -> Result) async throws -> Result {
    guard let projectRef = await self.projectIndex(name: projectName) else {
      throw ProjectAccessError.noProject(named: projectName)
    }
    return try await self.withProject(projectRef, cb)
  }

  public mutating func withProject<Result>(named projectName: String, _ cb: (inout Project) async throws -> Result) async throws -> Result {
    guard let projectRef = await self.projectIndex(name: projectName) else {
      throw ProjectAccessError.noProject(named: projectName)
    }
    return try await self.withProject(projectRef, cb)
  }

  public func withCurrentProject<Result>(_ cb: (borrowing Project) async throws -> Result) async throws -> Result {
    guard let currentProject = self.currentProjectIndex else {
      throw ProjectAccessError.noDefaultProject
    }
    return try await self.withProject(currentProject, cb)
  }

  public mutating func withCurrentProject<Result>(_ cb: (inout Project) async throws -> Result) async throws -> Result {
    guard let currentProject = self.currentProjectIndex else {
      throw ProjectAccessError.noDefaultProject
    }
    return try await self.withProject(currentProject, cb)
  }

  // Access Target //

  public func withTarget<Result>(_ target: TargetRef, _ cb: (borrowing any Target) async throws -> Result) async rethrows -> Result {
    try await self.withProject(target.project) { (project: borrowing Project) async throws in
      try await project.withTarget(target.target, cb)
    }
  }

  public mutating func withTarget<Result>(_ target: TargetRef, _ cb: (inout any Target) async throws -> Result) async rethrows -> Result {
    try await self.withProject(target.project) { (project: inout Project) async throws in
      try await project.withTarget(target.target, cb)
    }
  }

  public func withLibrary<Result>(_ target: TargetRef, _ cb: (borrowing any Library) async throws -> Result) async rethrows -> Result {
    try await self.withProject(target.project) { (project: borrowing Project) async throws in
      try await project.withLibrary(target.target, cb)
    }
  }

  public func withProjectAndLibrary<Result>(_ target: TargetRef, _ cb: (borrowing Project, borrowing any Library) async throws -> Result) async rethrows -> Result {
    try await self.withProject(target.project) { (project: borrowing Project) async throws in
      try await project.withLibrary(target.target) { (target: borrowing any Library) async throws in
        try await cb(project, target)
      }
    }
  }

  public func withProjectAndTarget<Result>(_ target: TargetRef, _ cb: (borrowing Project, borrowing any Target) async throws -> Result) async rethrows -> Result {
    try await self.withProject(target.project) { (project: borrowing Project) async throws in
      try await project.withTarget(target.target) { (target: borrowing any Target) async throws in
        try await cb(project, target)
      }
    }
  }
}
