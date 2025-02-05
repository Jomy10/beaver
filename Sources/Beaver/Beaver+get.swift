extension Beaver {
  public func projectIndex(name: String) async -> Int? {
    await self.projects.read { projects in
      projects.firstIndex(where: { $0.name == name })
    }
  }

  public func projectRef(name: String) async -> ProjectRef? {
    await self.projectIndex(name: name)
  }

  public func projectName(_ idx: ProjectRef) async -> String {
    await self.projects.read { projects in
      projects.withElement(idx) { $0.name }
    }
  }

  public func unsafeProjectName(_ idx: ProjectRef) -> String {
    self.projects.withUnsafeInnerValue { proj in proj.withElement(idx) { $0.name } }
  }

  public func targetIndex(name: String, project: ProjectRef) async -> Int? {
    await self.withProject(project) { (project: borrowing AnyProject) in
      await project.targetIndex(name: name)
    }
  }

  public func targetName(_ ref: TargetRef) async -> String? {
    await self.withProject(ref.project) { (project: borrowing AnyProject) in
      await project.targetName(ref.target)
    }
  }
}
