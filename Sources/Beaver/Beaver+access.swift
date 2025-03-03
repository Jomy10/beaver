extension Beaver {
  // Access project //

  public func withProject<Result>(_ index: ProjectRef, _ cb: (borrowing AnyProject) async throws -> Result) async rethrows -> Result {
    try await self.projects.read { projects in
      try await cb(projects.buffer[index])
    }
  }

  public func withProject<Result>(_ index: ProjectRef, _ cb: (inout AnyProject) async throws -> Result) async rethrows -> Result {
    try await self.projects.write { projects in
      try await cb(&projects.buffer[index])
    }
  }

  public func withCurrentProject<Result>(_ cb: (borrowing AnyProject) async throws -> Result) async throws -> Result {
    guard let currentProject = self.currentProjectIndex else {
      throw ProjectAccessError.noDefaultProject
    }
    return try await self.withProject(currentProject, cb)
  }

  public func withCurrentProject<Result>(_ cb: (inout AnyProject) async throws -> Result) async throws -> Result {
    guard let currentProject = self.currentProjectIndex else {
      throw ProjectAccessError.noDefaultProject
    }
    return try await self.withProject(currentProject, cb)
  }

  // Access Target //

  public func withTarget<Result>(_ target: TargetRef, _ cb: (borrowing AnyTarget) async throws -> Result) async rethrows -> Result {
    try await self.withProject(target.project) { (project: borrowing AnyProject) async throws in
      try await project.withTarget(target.target, cb)
    }
  }

  public func withTarget<Result>(_ target: TargetRef, _ cb: (inout AnyTarget) async throws -> Result) async rethrows -> Result {
    try await self.withProject(target.project) { (project: inout AnyProject) async throws in
      try await project.withTarget(target.target, cb)
    }
  }

  public func withLibrary<Result>(_ target: TargetRef, _ cb: (borrowing AnyLibrary) async throws -> Result) async rethrows -> Result {
    try await self.withProject(target.project) { (project: borrowing AnyProject) async throws in
      try await project.withLibrary(target.target, cb)
    }
  }

  // Access project and target //

  public func withProjectAndLibrary<Result>(_ target: TargetRef, _ cb: (borrowing AnyProject, borrowing AnyLibrary) async throws -> Result) async rethrows -> Result {
    try await self.withProject(target.project) { (project: borrowing AnyProject) async throws in
      let projectPtr = withUnsafePointer(to: project) { $0 }
      return try await project.withLibrary(target.target) { (target: borrowing AnyLibrary) async throws in
        try await cb(projectPtr.pointee, target)
      }
    }
  }

  public func withProjectAndExecutable<Result>(_ target: TargetRef, _ cb: (borrowing AnyProject, borrowing AnyExecutable) async throws -> Result) async rethrows -> Result {
    try await self.withProject(target.project) { (project: borrowing AnyProject) async throws in
      let projectPtr = withUnsafePointer(to: project) { $0 }
      return try await project.withExecutable(target.target) { (target: borrowing AnyExecutable) async throws in
        try await cb(projectPtr.pointee, target)
      }
    }
  }

  public func withProjectAndTarget<Result>(_ target: TargetRef, _ cb: (borrowing AnyProject, borrowing AnyTarget) async throws -> Result) async rethrows -> Result {
    return try await self.withProject(target.project) { (project: borrowing AnyProject) in
      let projectPtr = withUnsafePointer(to: project) { $0 }
      return try await project.withTarget(target.target) { (target: borrowing AnyTarget) in
        return try await cb(projectPtr.pointee, target)
      }
    }
  }

  public func withProjectAndLibrary<Result>(cmakeId: String, _ cb: (borrowing CMakeProject, borrowing CMakeLibrary) async throws -> Result) async throws -> Result {
    var val: Result? = nil
    try await self.projects.read { projects in
      try await projects.forEachUntil { project in
        switch (project) {
          case .cmake(let cmakeProject):
            let cmakeProjectPtr = withUnsafePointer(to: cmakeProject) { $0 }
            try await cmakeProject.loopTargetsUntil { (target: borrowing AnyTarget) -> Bool in
              switch (target) {
                case .library(let lib):
                  switch (lib) {
                    case .cmake(let cmakeLib):
                      if cmakeLib.cmakeId == cmakeId {
                        val = try await cb(cmakeProjectPtr.pointee, cmakeLib)
                        return true
                      } else {
                        return false
                      }
                    default: return false
                  }
                default: return false
              }
            }
            return val != nil
          default: return false
        }
      }
    }
    if let val = val {
      return val
    } else {
      throw TargetAccessError.noCMakeLibrary(cmakeId: cmakeId)
    }
  }

  // Loop //

  public func loopProjects(_ cb: (borrowing AnyProject) async throws -> Void) async rethrows {
    try await self.projects.read { projects in
      try await projects.forEach { project in
        try await cb(project)
      }
    }
  }

  public func loopTargets(_ cb: (borrowing AnyTarget) async throws -> Void) async rethrows {
    try await self.projects.read { projects in
      try await projects.forEach { project in
        try await project.loopTargets(cb)
      }
    }
  }

  public func loopProjectsAndTargets(_ cb: (borrowing AnyProject, borrowing AnyTarget) async throws -> Void) async rethrows {
    try await self.projects.read { projects in
      try await projects.forEach { project in
        try await project.loopTargets { target in
          try await cb(project, target)
        }
      }
    }
  }

  public func loopProjectsAndTargets<Result>(_ cb: (borrowing AnyProject, borrowing AnyTarget) async throws -> Result) async rethrows -> [Result] {
    var ret: [Result] = []
    try await self.projects.read { projects in
      try await projects.forEach { project in
        try await project.loopTargets { target in
          let val = try await cb(project, target)
          ret.append(val)
        }
      }
    }
    return ret
  }
}
