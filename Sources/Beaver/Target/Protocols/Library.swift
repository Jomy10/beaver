import Foundation

public protocol Library: ~Copyable, Target where ArtifactType == LibraryArtifactType {
  /// The linker flags only for this library, not any of its dependencies
  func linkAgainstLibrary(projectBuildDir: borrowing URL, artifact: LibraryArtifactType) -> [String]
  func publicCflags(projectBaseDir: borrowing URL) async throws -> [String]
}

extension Library where Self: ~Copyable {
  public var type: TargetType { .library }

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
    }
  }

  public func ninjaTarget<P: Project & ~Copyable>(inProject project: borrowing P, artifact: eArtifactType) -> String {
    switch (artifact) {
      case .library(let artifact): return self.ninjaTarget(inProject: project, artifact: artifact)
      default: fatalError("invalid artifact for library: \(artifact)")
    }
  }
}
