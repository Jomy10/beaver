import Foundation

public protocol Target: ~Copyable, Sendable {
  associatedtype ArtifactType: Equatable, Sendable

  var name: String { get }
  var description: String? { get }
  var homepage: URL? { get }
  var version: Version? { get }
  var language: Language { get }
  var artifacts: [ArtifactType] { get }
  var dependencies: [LibraryRef] { get }

  /// Use the dependency graph to build this target
  var useDependencyGraph: Bool { get }
  /// When using dependency graph, set this if this target spawns multiple threads in the `build` command
  var spawnsMoreThreadsWithGlobalThreadManager: Bool { get }

  /// Wether this target is buildable. If the target is not buildable and is attempted to be built, it will throw an error
  var buildableTarget: Bool { get }

  func build(baseDir: borrowing URL, buildDir: borrowing URL, context: borrowing Beaver) async throws
  func build(artifact: ArtifactType, baseDir: borrowing URL, buildDir: borrowing URL, context: borrowing Beaver) async throws

  func artifactOutputDir(projectBuildDir: URL, forArtifact artifact: ArtifactType?) async throws -> URL
  func artifactURL(projectBuildDir: URL, _ artifact: ArtifactType) async throws -> URL


  /// Provide all linker flags for linking this target.
  /// Used internally in linking phase
  func allLinkerFlags(context: borrowing Beaver, visited: inout Set<LibraryRef>) async throws -> [String]
}

struct NonBuildableTargetError: Error {
  let targetName: String
}

extension Target {
  public var spawnsMoreThreadsWithGlobalThreadManager: Bool { false }

  /// Implementation for build, calling all artifacts synchronously
  public func buildArtifactsSync(baseDir: borrowing URL, buildDir: borrowing URL, context: borrowing Beaver) async throws {
    for artifact in self.artifacts {
      try await self.build(artifact: artifact, baseDir: baseDir, buildDir: buildDir, context: context)
    }
  }

  public func buildArtifactsAsync(baseDir: URL, buildDir: URL, context: borrowing Beaver) async throws {
    try await borrow2N(self, context, n: self.artifacts.count) { (i, target, context) in
      try await target.build(artifact: target.artifacts[i], baseDir: copy baseDir, buildDir: copy buildDir, context: context)
    }
  }
}
