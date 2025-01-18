import Foundation

extension Beaver {
  public func customDebugString(withSources: Bool) async -> String {
    """
    \(await projects.read { projects in
      await projects.map { project in
        await project.customDebugString(withSources: withSources)
      }.joined(separator: "\n")
    })
    """
  }

  public var debugString: String {
    get async {
      await self.customDebugString(withSources: false)
    }
  }
}

extension Project {
  public func customDebugString(withSources: Bool) async -> String {
    """
    \(self.name)
    targets:
    \(await self.targets.read { targets in
      await targets.map { target in
        try! await target.customDebugString(withSourcesRelativeTo: self.baseDir).prependingRows(" ")
      }.joined(separator: "\n")
    })
    """
  }

  public var debugString: String {
    get async {
      await self.customDebugString(withSources: false)
    }
  }
}

extension Target {
  public func customDebugString(withSourcesRelativeTo baseDir: URL?) async throws -> String {
    var s = "\(self.name) (\(self.language))"
    if let baseDir = baseDir {
      if self is any CTarget {
        s += "\n  \((self as! any CTarget).sources)"
        s += "\n  \(try await (self as! any CTarget).collectSources(projectBaseDir: baseDir))"
      }
    }
    return s
  }

  public var debugString: String {
    get async {
      try! await self.customDebugString(withSourcesRelativeTo: nil)
    }
  }
}
