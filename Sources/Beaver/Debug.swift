import Foundation

// TODO: reimplement
//extension Beaver {
//  public func customDebugString(withSources: Bool, withDependencies: Bool) async -> String {
//    fatalError("TODO")
//    //"""
//    //\(await projects.read { projects in
//    //  await projects.map { project in
//    //    await project.customDebugString(withSources: withSources, withDependencies: withDependencies)
//    //  }.joined(separator: "\n")
//    //})
//    //"""
//  }

//  public var debugString: String {
//    get async {
//      await self.customDebugString(withSources: false, withDependencies: false)
//    }
//  }
//}

//extension BeaverProject {
//  public func customDebugString(withSources: Bool, withDependencies: Bool) async -> String {
//    """
//    \(self.name)
//    targets:
//    \(await self.targets.read { targets in
//      await targets.map { target in
//        await target.customDebugString(withSourcesRelativeTo: self.baseDir, withDependencies: withDependencies).prependingRows(" ")
//      }.joined(separator: "\n")
//    })
//    """
//  }

//  public var debugString: String {
//    get async {
//      await self.customDebugString(withSources: false, withDependencies: false)
//    }
//  }
//}

//extension Target {
//  public func customDebugString(withSourcesRelativeTo baseDir: URL?, withDependencies: Bool) async  -> String {
//    var s = "\(self.name) (\(self.language))"
//    if let baseDir = baseDir {
//      if self is any CTarget {
//        s += "\n  \((self as! any CTarget).sources)"
//        s += "\n  \((try? await (self as! any CTarget).collectSources(projectBaseDir: baseDir).map { $0.path }.joined(separator: ", ")) ?? "no sources")"
//      }
//    }
//    if withDependencies {
//      s += "\n  \(self.dependencies)"
//    }
//    return s
//  }

//  public var debugString: String {
//    get async {
//      await self.customDebugString(withSourcesRelativeTo: nil, withDependencies: false)
//    }
//  }
//}
