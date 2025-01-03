import Foundation

extension Sequence {
  func asyncMap<ResultType>(_ cb: (borrowing Element) async throws -> ResultType) async rethrows -> [ResultType] {
    var res: [ResultType] = []
    for el in self {
      res.append(try await cb(el))
    }
    return res
  }
}

func borrowN<NC: ~Copyable, Result>(_ nc: borrowing NC, n: Int, _ cb: (Int, borrowing NC) throws -> Result) rethrows -> [Result] {
  try (0..<n).map { i in
    try cb(i, nc)
  }
}

func borrow2N<NC1: ~Copyable, NC2: ~Copyable, Result>(
  _ nc1: borrowing NC1,
  _ nc2: borrowing NC2,
  n: Int,
  _ cb: (borrowing NC1, borrowing NC2) throws -> Result
) rethrows -> [Result] {
  try (0..<n).map { i in
    try cb(nc1, nc2)
  }
}

func borrow2N<NC1: ~Copyable, NC2: ~Copyable>(
  _ nc1: borrowing NC1,
  _ nc2: borrowing NC2,
  n: Int,
  _ cb: @escaping @Sendable (Int, borrowing NC1, borrowing NC2) async throws -> ()
) async throws {
  let nc1Ptr = UnsafeSendable(withUnsafePointer(to: nc1) { $0 })
  let nc2Ptr = UnsafeSendable(withUnsafePointer(to: nc2) { $0 })

  let tasks = await (0..<n).asyncMap { i in
    await GlobalThreadCounter.newProcess()
    return Task.detached(priority: .high) {
      try await cb(i, nc1Ptr.value.pointee, nc2Ptr.value.pointee)
    }
  }

  for (i, task) in tasks.enumerated() {
    switch (await task.result) {
      case .failure(let error):
        if i != tasks.count - 1 {
          for task in tasks[i...] {
            task.cancel()
            _ = await task.result
          }
          throw error
        }
      case .success(()):
        break
    }
  }
}

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
  /// When using dependency graph, set this if this target spawns multiple threads in the `build` command
  var spawnsMoreThreadsWithGlobalThreadManager: Bool { get }

  func build(baseDir: borrowing URL, buildDir: borrowing URL, context: borrowing Beaver) async throws
  func build(artifact: ArtifactType, baseDir: borrowing URL, buildDir: borrowing URL, context: borrowing Beaver) async throws

  func artifactOutputDir(projectBuildDir: URL, forArtifact artifact: ArtifactType?) async throws -> URL
  func artifactURL(projectBuildDir: URL, _ artifact: ArtifactType) async throws -> URL
}

extension Target {
  public var spawnsMoreThreadsWithGlobalThreadManager: Bool { false }

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
