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

  func buildStatements<P: Project & ~Copyable>(inProject project: borrowing P, context: borrowing Beaver) async throws -> BuildBackendBuilder

  func ninjaTarget<P: Project & ~Copyable>(inProject: borrowing P, artifact: eArtifactType) -> String
  //func build(
  //  inProject: borrowing some Project,
  //  projectBaseDir: borrowing URL,
  //  projectBuildDir: borrowing URL,
  //  context: borrowing Beaver
  //) async throws

  //func build(
  //  inProject: borrowing someProject,
  //  artifact: eArtifactType,
  //  projectBaseDir: borrowing URL,
  //  projectBuildDir: borrowing URL,
  //  context: borrowing Beaver
  //) async throws

  //func clean(projectBuildDir: borrowing URL, context: borrowing Beaver) async throws

  //func debugString(_ opts: DebugTargetOptions) -> String
}

extension TargetBase where Self: ~Copyable {
  public func ninjaTarget<P: Project & ~Copyable>(inProject project: borrowing P) -> String {
    "\(project.name):\(self.name)"
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

  /// Build the specific artifact
  //func build(
  //  inProject: borrowing some Project,
  //  artifact: ArtifactType,
  //  projectBaseDir: borrowing URL,
  //  projectBuildDir: borrowing URL,
  //  context: borrowing Beaver
  //) async throws

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

  // Build //
  /// Builds the artifact specified by the artifact type. Panics if the wrong artifact type is given. Only used internally
  //public func build(
  //  artifact: eArtifactType,
  //  projectBaseDir: borrowing URL,
  //  projectBuildDir: borrowing URL,
  //  context: borrowing Beaver
  //) async throws {
  //  try await self.build(artifact: artifact.as(Self.ArtifactType.self)!, projectBaseDir: projectBaseDir, projectBuildDir: projectBuildDir, context: context)
  //}

  //func buildArtifactsSync(baseDir: borrowing URL, buildDir: borrowing URL, context: borrowing Beaver) async throws {
  //  for artifact in self.artifacts {
  //    try await self.build(artifact: artifact, projectBaseDir: baseDir, projectBuildDir: buildDir, context: context)
  //  }
  //}

  //func buildArtifactsAsync(baseDir: borrowing URL, buildDir: borrowing URL, context: borrowing Beaver) async throws {
  //  let contextPtr = UnsafeSendable(withUnsafePointer(to: context) { $0 })
  //  let selfPtr = UnsafeSendable(withUnsafePointer(to: self) { $0 })
  //  try await withThrowingTaskGroup(of: Void.self) { [baseDir = copy baseDir, buildDir = copy buildDir] group in
  //    for i in 0..<self.artifacts.count {
  //      group.addTask {
  //        try await selfPtr.value.pointee.build(artifact: selfPtr.value.pointee.artifacts[i], projectBaseDir: baseDir, projectBuildDir: buildDir, context: contextPtr.value.pointee)
  //      }
  //    }

  //    try await group.waitForAll()
  //  }
  //}
}

extension Target where Self: ~Copyable {
  public func ninjaTarget<P: Project & ~Copyable>(inProject project: borrowing P, artifact: ArtifactType) -> String {
    "\(project.name):\(self.name):\(artifact)"
  }
}
