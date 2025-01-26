import Foundation

public protocol Library: ~Copyable, Target where ArtifactType == LibraryArtifactType {
  /// The linker flags only for this library, not any of its dependencies
  func linkAgainstLibrary(projectBuildDir: borrowing URL, artifact: LibraryArtifactType) -> [String]
  func publicCflags(projectBaseDir: borrowing URL) async throws -> [String]
}
