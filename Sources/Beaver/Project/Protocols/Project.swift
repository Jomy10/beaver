import Foundation

/// A general interface into a project. Commonly a `BeaverProject`, but other projects like
/// `CMakeProject` can also be specified in Beaver
public protocol Project: ~Copyable, Sendable {
  var id: Int { get set }
  var name: String { get }
  var baseDir: URL { get }
  var buildDir: URL { get }

  func clean(context: borrowing Beaver) async throws

  /// Builds all targets in a project
  func build(context: borrowing Beaver) async throws
  /// Builds the specified artifact of the specified target.
  /// If the ArtifactType doesn't match the target type, this function panics
  func build(
    _ targetRef: TargetRef.Ref,
    artifact: ArtifactType,
    context: borrowing Beaver
  ) async throws
  /// Builds all artifacts of the specified target
  func build(
    _ targetRef: TargetRef.Ref,
    context: borrowing Beaver
  ) async throws

  /// Runs the default executable in this target, if any
  func getOnlyExecutable() async throws -> Int

  func withTarget<Result>(_ ref: TargetRef.Ref, _ cb: (borrowing AnyTarget) async throws -> Result) async rethrows -> Result
  mutating func withTarget<Result>(_ ref: TargetRef.Ref, _ cb: (inout AnyTarget) async throws -> Result) async rethrows -> Result
  func withLibrary<Result>(_ ref: TargetRef.Ref, _ cb: (borrowing AnyLibrary) async throws -> Result) async throws -> Result
  func withExecutable<Result>(_ ref: TargetRef.Ref, _ cb: (borrowing AnyExecutable) async throws -> Result) async throws -> Result

  func loopTargets(_ cb: (borrowing AnyTarget) async throws -> Void) async rethrows

  func targetIndex(name: String) async -> Int?
  func targetName(_ index: Int) async -> String?
  func targetNames() async -> [String]
}

extension Project where Self: ~Copyable {
  public func run(args: [String], context: borrowing Beaver) async throws {
    try await self.run(try await self.getOnlyExecutable(), args: args, context: context)
  }

  public func run(_ targetIndex: Int, args: [String], context: borrowing Beaver) async throws {
    try await self.build(targetIndex, artifact: .executable(.executable), context: context)

    try await self.withExecutable(targetIndex) { (target: borrowing AnyExecutable) in
      try await target.run(projectBuildDir: self.buildDir, args: args)
    }
  }
}
