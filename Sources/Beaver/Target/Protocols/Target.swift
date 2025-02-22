import Foundation
import Utils

public enum TargetType: Int8 {
  case library
  case executable
}

public protocol TargetBase: ~Copyable, Sendable {
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

  var eArtifacts: [eArtifactType] { get }

  var dependencies: [Dependency] { get }

  var type: TargetType { get }

  func buildStatements<P: Project & ~Copyable>(inProject project: borrowing P, context: Beaver) async throws -> BuildBackendBuilder

  func ninjaTarget<P: Project & ~Copyable>(inProject: borrowing P, artifact: eArtifactType) -> String
}

extension TargetBase where Self: ~Copyable {
  public func ninjaTarget<P: Project & ~Copyable>(inProject project: borrowing P) -> String {
    "\(project.name):\(self.name)"
  }

  @inline(__always)
  func loopUniqueDependenciesRecursive(context: Beaver, _ cb: (Dependency) async throws -> Void) async throws {
    var visited = Set<Dependency>()
    try await self.__loopUniqueDependenciesRecursive(context: context, visited: &visited, cb)
  }

  @inline(__always)
  func __loopUniqueDependenciesRecursive(context: Beaver, visited: inout Set<Dependency>,  _ cb: (Dependency) async throws -> Void) async throws {
    for dependency in self.dependencies {
      if !visited.contains(dependency) {
        visited.insert(dependency)
        try await cb(dependency)
        if case .library(let libTarget) = dependency {
          try await context.withTarget(libTarget.target) { (target: borrowing AnyTarget) in
            try await target.__loopUniqueDependenciesRecursive(context: context, visited: &visited, cb)
          }
        }
      }
    }
  }
}

/// A target which produces artifacts when building
public protocol Target: TargetBase, ~Copyable, Sendable {
  associatedtype ArtifactType: ArtifactTypeProtocol

  var artifacts: [ArtifactType] { get }

  func artifactOutputDir(projectBuildDir: borrowing URL, artifact: ArtifactType) -> URL?
  func artifactURL(projectBuildDir: borrowing URL, artifact: ArtifactType) -> URL?
}

extension Target where Self: ~Copyable {
  public var eArtifacts: [eArtifactType] {
    self.artifacts.map { $0.asArtifactType() }
  }

  // Identification //
  var ref: TargetRef {
    TargetRef(target: self.id, project: self.projectId)
  }
}

extension Target where Self: ~Copyable {
  public func ninjaTarget<P: Project & ~Copyable>(inProject project: borrowing P, artifact: ArtifactType) -> String {
    "\(project.name):\(self.name):\(artifact)"
  }
}
