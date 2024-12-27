import Foundation

public protocol Executable: Target {
  associatedtype ArtifactType = ExecutableArtifactType

  func artifactURL(projectBuildDir: URL, _ artifact: ExecutableArtifactType) async throws -> URL
}

public enum ExecutableArtifactType: Equatable, Hashable, Sendable {
  case executable
  /// a macOS app
  case app
}
