import Foundation

public protocol Executable: Target where ArtifactType == ExecutableArtifactType {
  func artifactURL(projectBuildDir: URL, _ artifact: ExecutableArtifactType) async throws -> URL
}
