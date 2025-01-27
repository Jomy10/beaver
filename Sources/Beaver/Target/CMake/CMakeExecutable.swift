import Foundation
import Utils

public struct CMakeExecutable: CMakeTarget, Executable, ~Copyable, Sendable {
  public var name: String
  public var description: String? { nil }
  public var homepage: URL? { nil }
  public var version: Version? { nil }
  public var license: String? { nil }
  public let language: Language

  public var id: Int
  public var projectId: ProjectRef

  public var dependencies: [Dependency] { [] }

  public var artifacts: [ArtifactType]

  public typealias ArtifactType = ExecutableArtifactType

  init(
    name: String,
    language: Language,
    projectId: ProjectRef = -1,
    id: Int = -1,
    artifact: ArtifactType
  ) {
    self.name = name
    self.language = language
    self.projectId = projectId
    self.id = id
    self.artifacts = [artifact]
  }

  // TODO: get from targetDefinition
  public func artifactURL(projectBuildDir: borrowing URL, artifact: ExecutableArtifactType) -> URL? {
    return projectBuildDir.appending(path: "\(self.name)\(artifact.extension)")
  }
}
