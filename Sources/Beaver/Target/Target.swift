import Foundation

public protocol Target: ~Copyable, Sendable {
  associatedtype ArtifactType: ArtifactTypeProtocol

  var id: Int { get set }
  var projectId: Int { get set }
  var ref: TargetRef { get }

  var name: String { get }
  var description: String? { get }
  var homepage: URL? { get }
  var version: Version? { get }
  var language: Language { get }
  var artifacts: [ArtifactType] { get }
  var dependencies: [Dependency] { get }

  /// Use the dependency graph to build this target
  @available(*, deprecated)
  var useDependencyGraph: Bool { get }
  /// When using dependency graph, set this if this target spawns multiple threads in the `build` command
  var spawnsMoreThreadsWithGlobalThreadManager: Bool { get }

  /// Wether this target is buildable. If the target is not buildable and is attempted to be built, it will throw an error
  var buildableTarget: Bool { get }

  func build(baseDir: borrowing URL, buildDir: borrowing URL, context: borrowing Beaver) async throws
  /// Builds the specified artifact
  ///
  /// # Returns
  /// True if the artifact was rebuilt, false if no source files were changed and thus the artifact was not created again
  func build(artifact: ArtifactType, baseDir: borrowing URL, buildDir: borrowing URL, context: borrowing Beaver) async throws -> Bool

  func artifactOutputDir(projectBuildDir: URL, forArtifact artifact: ArtifactType?) async throws -> URL
  func artifactURL(projectBuildDir: URL, _ artifact: ArtifactType) async throws -> URL

  /// Provide all linker flags for linking this target.
  /// Used internally in linking phase
  func allLinkerFlags(context: borrowing Beaver, visited: inout Set<Dependency>) async throws -> [String]
  /// All languages that are present in this library/executable and its dependencies.
  /// This is used to determine addition linker flags
  func languages(context: borrowing Beaver) async throws -> [Language]

  func clean(buildDir: borrowing URL, context: borrowing Beaver) async throws
}

struct NonBuildableTargetError: Error {
  let targetName: String
}

extension Target {
  public var ref: TargetRef {
    TargetRef(target: self.id, project: self.projectId)
  }
  public var spawnsMoreThreadsWithGlobalThreadManager: Bool { false }

  /// Implementation for build, calling all artifacts synchronously
  public func buildArtifactsSync(baseDir: borrowing URL, buildDir: borrowing URL, context: borrowing Beaver) async throws {
    for artifact in self.artifacts {
      _ = try await self.build(artifact: artifact, baseDir: baseDir, buildDir: buildDir, context: context)
    }
  }

  public func buildArtifactsAsync(baseDir: URL, buildDir: URL, context: borrowing Beaver) async throws {
    try await borrow2N(self, context, n: self.artifacts.count) { (i, target, context) in
      _ = try await target.build(artifact: target.artifacts[i], baseDir: copy baseDir, buildDir: copy buildDir, context: context)
    }
  }

  public func languages(context: borrowing Beaver) async throws -> [Language] {
    return try await self.dependencies.asyncFlatMap { dep in
      return try await context.withLibrary(dep.library) { library in
        var dependencyLanguages = try await library.languages(context: context)
        dependencyLanguages.append(library.language)
        return dependencyLanguages
      }
    }.unique
  }
}

/// An invalid language was passed to a target expecting a specific set of languages
public struct InvalidLanguage: Error {
  let language: Language
}
