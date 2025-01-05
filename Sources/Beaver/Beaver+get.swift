extension Beaver {
  func projectIndex(name: String) async -> Int? {
    await self.projects.read { projects in
      projects.firstIndex(where: { $0.name == name })
    }
  }

  func projectRef(name: String) async -> ProjectRef? {
    await self.projectIndex(name: name)
  }

  func projectName(_ idx: ProjectRef) async -> String? {
    await self.projects.read { projects in
      projects.withElement(idx) { $0.name }
    }
  }

  func targetIndex(name: String, project: ProjectRef) async -> Int? {
    await self.withProject(project) { (project: borrowing Project) in
      await project.targetIndex(name: name)
    }
  }

  func targetName(_ ref: TargetRef) async -> String? {
    await self.withProject(ref.project) { (project: borrowing Project) in
      await project.targetName(ref.target)
    }
  }

  func isBuildable(target: TargetRef) async -> Bool {
    await self.withTarget(target) { (target: borrowing any Target) async in target.buildableTarget }
  }
}
