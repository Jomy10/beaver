public struct TargetRef: Identifiable, Hashable, Equatable, Sendable {
  public let target: Int
  public let project: ProjectRef

  public var id: Self { self }
}

extension TargetRef {
  public func description(context: borrowing Beaver) async -> String? {
    guard let targetName = await context.targetName(self) else { return nil }
    guard let projectName = await context.projectName(self.project) else { return nil }
    return if context.currentProjectIndex == self.project {
      targetName
    } else {
      projectName + ":" + targetName
    }
  }
}

public struct Dependency: Hashable, Equatable, Sendable {
  let library: TargetRef
  let artifact: LibraryArtifactType

  public init(library: TargetRef, artifact: LibraryArtifactType) {
    self.library = library
    self.artifact = artifact
  }

  public enum ParsingError: Error {
    case unexpectedNoComponents
    case malformed(String)
    /// No project exists with the specified name
    case unknownProject(String)
    case unknownTarget(name: String, inProject: String)
    case noDefaultProject
  }
}

extension Beaver {
  public func dependency(_ target: String, artifact: LibraryArtifactType = .staticlib) async throws -> Dependency {
    let components = target.split(separator: ":")
    switch (components.count) {
      case 0:
        throw Dependency.ParsingError.unexpectedNoComponents
      case 1:
        guard let currentProject = self.currentProjectIndex else {
          throw Dependency.ParsingError.noDefaultProject
        }
        guard let targetIndex = await self.targetIndex(name: target, project: currentProject) else {
          let projectName = await self.projectName(currentProject)!
          throw Dependency.ParsingError.unknownTarget(name: target, inProject: projectName)
        }
        return Dependency(library: TargetRef(target: targetIndex, project: currentProject), artifact: artifact)
      case 2:
        let name = String(components[1])
        let projectName = String(components[0])
        guard let projectIndex = await self.projectIndex(name: projectName) else {
          throw Dependency.ParsingError.unknownProject(projectName)
        }
        guard let targetIndex = await self.targetIndex(name: name, project: projectIndex) else {
          throw Dependency.ParsingError.unknownTarget(name: name, inProject: projectName)
        }
        return Dependency(library: TargetRef(target: targetIndex, project: projectIndex), artifact: artifact)
      default:
        throw Dependency.ParsingError.malformed(target)
    }
  }
}
