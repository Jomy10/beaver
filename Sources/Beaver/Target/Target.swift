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

  var useDependencyGraph: Bool { get }

  func build(baseDir: borrowing URL, buildDir: borrowing URL, context: borrowing Beaver) async throws
  func build(artifact: ArtifactType, baseDir: borrowing URL, buildDir: borrowing URL, context: borrowing Beaver) async throws

  func artifactOutputDir(projectBuildDir: URL, forArtifact artifact: ArtifactType?) async throws -> URL
  func artifactURL(projectBuildDir: URL, _ artifact: ArtifactType) async throws -> URL
}

extension Target {
  public func build(baseDir: URL, buildDir: URL, context: borrowing Beaver) async throws {
    for artifact in self.artifacts {
      try await self.build(artifact: artifact, baseDir: baseDir, buildDir: buildDir, context: context)
    }
  }
}

public enum Language: Sendable {
  case c
  case swift
  case other(String)
}

extension Language: Equatable, Hashable {
  public static func ==(lhs: Self, rhs: Self) -> Bool {
    switch (lhs) {
      case .c: return rhs == .c
      case .swift: return rhs == .swift
      case .other(let s):
        guard case .other(let sOther) = rhs else {
          return false
        }
        return s == sOther
    }
  }
}
