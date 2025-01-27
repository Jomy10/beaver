import Foundation

public protocol Library: ~Copyable, Target where ArtifactType == LibraryArtifactType {
  /// The linker flags only for this library, not any of its dependencies
  func linkAgainstLibrary(projectBuildDir: borrowing URL, artifact: LibraryArtifactType) -> [String]
  func publicCflags(projectBaseDir: borrowing URL) async throws -> [String]
}

extension Library where Self: ~Copyable {
  public var eArtifacts: [eArtifactType] {
    self.artifacts.map { .library($0) }
  }

  public func linkAgainstArtifact(projectBuildDir: borrowing URL, artifact: LibraryArtifactType) -> [String] {
    switch (artifact) {
      case .dynlib:
        return ["-L\(self.artifactOutputDir(projectBuildDir: projectBuildDir, artifact: artifact)!.path)", "-l\(self.name)"]
      case .staticlib:
        return [self.artifactURL(projectBuildDir: projectBuildDir, artifact: artifact)!.path]
      case .framework:
        return ["-F\(self.artifactOutputDir(projectBuildDir: projectBuildDir, artifact: artifact)!.path)", "-framework", self.name]
      case .xcframework:
        fatalError("todo")
      case .pkgconfig:
        fatalError("Can't link against pkgconfig (bug)")
      case .staticlanglib(_): fallthrough
      case .dynamiclanglib(_):
        fatalError("Found incompatible artifact for \(Self.self) (bug)")
    }
  }
}
