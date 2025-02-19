import Foundation
import Utils

public struct CMakeLibrary: CMakeTarget, Library, ~Copyable, Sendable {
  public var name: String
  public var description: String? { nil }
  public var homepage: URL? { nil }
  public var version: Version? { nil }
  public var license: String? { nil }
  public let language: Language

  public var id: Int
  public var projectId: ProjectRef
  public var cmakeId: String

  public var artifacts: [ArtifactType]
  public var _artifactURL: URL

  /// Used for linking against this dependency
  public var linkerFlags: [String]
  public var cflags: [String]
  public var dependencies: [Dependency]

  public typealias ArtifactType = LibraryArtifactType

  init(
    cmakeId: String,
    name: String,
    language: Language,
    projectId: ProjectRef = -1,
    id: Int = -1,
    artifact: ArtifactType,
    artifactURL: URL,
    linkerFlags: [String],
    cflags: [String],
    dependencies: [Dependency]
  ) {
    self.cmakeId = cmakeId
    self.name = name
    self.language = language
    self.projectId = projectId
    self.id = id
    self.artifacts = [artifact]
    self.linkerFlags = linkerFlags
    self.cflags = cflags
    self._artifactURL = artifactURL
    self.dependencies = dependencies
  }

  public func artifactURL(projectBuildDir: borrowing URL, artifact: LibraryArtifactType) -> URL? {
    return self._artifactURL
    //return projectBuildDir.appending(path: "lib\(self.name)\(artifact.extension)")
  }

  public func linkAgainstLibrary(projectBuildDir: borrowing URL, artifact: ArtifactType) -> [String] {
    self.linkAgainstArtifact(projectBuildDir: projectBuildDir, artifact: artifact) + self.linkerFlags
  }

  public func linkAgainstLibrary(projectBuildDir: borrowing URL) -> [String] {
    self.linkAgainstArtifact(projectBuildDir: projectBuildDir, artifact: self.artifacts[0]) + self.linkerFlags
  }

  public func publicCflags(projectBaseDir: borrowing URL) async throws -> [String] {
    self.cflags
  }

  //public func clean(projectBuildDir: borrowing URL, context: borrowing Beaver) async throws {
  //  if FileManager.default.exists(at: projectBuildDir) {
  //    try FileManager.default.removeItem(at: copy projectBuildDir)
  //  }
  //}
}
