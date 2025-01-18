import Foundation

/// A target which produces artifacts when building
public protocol Target: ~Copyable, Sendable {
  // General info //
  var name: String { get }
  var description: String? { get }
  var homepage: URL? { get }
  var version: Version? { get }
  var license: String? { get }
  var language: Language { get }

  // Identification //
  /// The target id in the project
  var id: Int { get set }
  var projectId: ProjectRef { get set }

  associatedtype ArtifactType: ArtifactTypeProtocol
  var artifacts: [ArtifactType] { get }

  var dependencies: [Dependency] { get }

  func build(
    projectBaseDir: borrowing URL,
    projectBuildDir: borrowing URL,
    context: borrowing Beaver
  ) async throws
  func build(
    artifact: ArtifactType,
    projectBaseDir: borrowing URL,
    projectBuildDir: borrowing URL,
    context: borrowing Beaver
  ) async throws
  func clean(projectBuildDir: borrowing URL, context: borrowing Beaver) async throws

  func artifactOutputDir(projectBuildDir: borrowing URL, artifact: ArtifactType) -> URL?
  func artifactURL(projectBuildDir: borrowing URL, artifact: ArtifactType) -> URL?
}

extension Target {
  // Identification //
  var ref: TargetRef {
    TargetRef(target: self.id, project: self.projectId)
  }

  // Build //
  func build(
    artifact: eArtifactType,
    projectBaseDir: borrowing URL,
    projectBuildDir: borrowing URL,
    context: borrowing Beaver
  ) async throws {
    try await self.build(artifact: artifact.as(Self.ArtifactType.self)!, projectBaseDir: projectBaseDir, projectBuildDir: projectBuildDir, context: context)
  }

  public func buildArtifactsSync(baseDir: borrowing URL, buildDir: borrowing URL, context: borrowing Beaver) async throws {
    for artifact in self.artifacts {
      _ = try await self.build(artifact: artifact, projectBaseDir: baseDir, projectBuildDir: buildDir, context: context)
    }
  }

  // TODO: rewrite
  public func buildArtifactsAsync(baseDir: URL, buildDir: URL, context: borrowing Beaver) async throws {
    // TODO: task queue
    try await borrow2N(self, context, n: self.artifacts.count) { (i, target, context) in
      _ = try await target.build(artifact: target.artifacts[i], projectBaseDir: copy baseDir, projectBuildDir: copy buildDir, context: context)
    }
  }

  @inline(__always)
  func loopUniqueDependenciesRecursive(context: borrowing Beaver, _ cb: (Dependency) async throws -> Void) async throws {
    var visited = Set<Dependency>()
    try await self.__loopUniqueDependenciesRecursive(context: context, visited: &visited, cb)
  }

  @inline(__always)
  func __loopUniqueDependenciesRecursive(context: borrowing Beaver, visited: inout Set<Dependency>,  _ cb: (Dependency) async throws -> Void) async throws {
    for dependency in self.dependencies {
      if !visited.contains(dependency) {
        visited.insert(dependency)
        try await cb(dependency)
        if case .library(let libTarget) = dependency {
          try await context.withTarget(libTarget.target) { (target: borrowing any Target) in
            try await target.__loopUniqueDependenciesRecursive(context: context, visited: &visited, cb)
          }
        }
      }
    }
  }

  //public func dependencyLinkerFlags(context: borrowing Beaver) async throws -> [String] {
  //  var linkerFlags: [String] = []
  //  self.loopUniqueDependenciesRecursive(context: context) { (dependency, library, projectBuildDir) in
  //    linkerFlags.append(contentsOf: library.linkAgainstLibrary(projectBuildDir: projectBuildDir, artifact: dependency.artifact))
  //  }
  //  return linkerFlags
  //}
}
