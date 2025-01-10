extension Beaver {
  public func projectIndex(name: String) async -> Int? {
    await self.projects.read { projects in
      projects.firstIndex(where: { $0.name == name })
    }
  }

  public func projectRef(name: String) async -> ProjectRef? {
    await self.projectIndex(name: name)
  }

  public func projectName(_ idx: ProjectRef) async -> String? {
    await self.projects.read { projects in
      projects.withElement(idx) { $0.name }
    }
  }

  public func targetIndex(name: String, project: ProjectRef) async -> Int? {
    await self.withProject(project) { (project: borrowing Project) in
      await project.targetIndex(name: name)
    }
  }

  public func targetName(_ ref: TargetRef) async -> String? {
    await self.withProject(ref.project) { (project: borrowing Project) in
      await project.targetName(ref.target)
    }
  }

  func isBuildable(target: TargetRef) async -> Bool {
    await self.withTarget(target) { (target: borrowing any Target) async in target.buildableTarget }
  }

  //public func evaluateTarget(targetName: String) async throws -> TargetRef {
  //  guard let currentProject = self.currentProjectIndex else {
  //    throw BuildError.noDefaultTarget
  //  }
  //  guard let index = await self.targetIndex(name: targetName, project: currentProject) else {
  //    throw BuildError.noTarget(named: targetName)
  //  }
  //  return TargetRef(target: index, project: currentProject)
  //}
}
