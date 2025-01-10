extension Beaver {
  public var debugString: String {
    get async {
      """
      \(await projects.read { projects in
        await projects.map { project in
          await project.debugString
        }.joined(separator: "\n")
      })
      """
    }
  }
}

extension Project {
  public var debugString: String {
    get async {
      """
      \(self.name)
      targets:
      \(await self.targets.read { targets in
        await targets.map { target in
          " " + target.debugString
        }.joined(separator: "\n")
      })
      """
    }
  }
}

extension Target {
  public var debugString: String {
    "\(self.name) (\(self.language))"
  }
}
