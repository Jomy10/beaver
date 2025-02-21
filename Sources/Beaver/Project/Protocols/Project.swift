import Foundation

/// A general interface into a project. Commonly a `BeaverProject`, but other projects like
/// `CMakeProject` can also be specified in Beaver
public protocol Project: ~Copyable, Sendable {
  var id: Int { get set }
  var name: String { get }
  var baseDir: URL { get }

  func buildStatements(context: Beaver) async throws -> BuildBackendBuilder

  /// Runs the default executable in this target, if any
  func getOnlyExecutable() async throws -> Int

  func withTarget<Result>(_ ref: TargetRef.Ref, _ cb: (borrowing AnyTarget) async throws -> Result) async rethrows -> Result
  mutating func withTarget<Result>(_ ref: TargetRef.Ref, _ cb: (inout AnyTarget) async throws -> Result) async rethrows -> Result
  func withLibrary<Result>(_ ref: TargetRef.Ref, _ cb: (borrowing AnyLibrary) async throws -> Result) async throws -> Result
  func withExecutable<Result>(_ ref: TargetRef.Ref, _ cb: (borrowing AnyExecutable) async throws -> Result) async throws -> Result

  @discardableResult
  func loopTargets<Result>(_ cb: (borrowing AnyTarget) async throws -> Result) async rethrows -> [Result]

  func targetIndex(name: String) async -> Int?
  func targetName(_ index: Int) async -> String
  func targetNames() async -> [String]

  func buildDir(_ context: Beaver) -> URL
}

extension Project where Self: ~Copyable {
  public func buildDir(_ context: Beaver) -> URL {
    context.buildDir(for: self.name)
  }

  public func run(args: [String], context: Beaver) async throws {
    try await self.run(try await self.getOnlyExecutable(), args: args, context: context)
  }

  public func run(_ targetIndex: Int, args: [String], context: Beaver) async throws {
    //try await self.build(targetIndex, artifact: .executable(.executable), context: context)
    try await context.build(TargetRef(target: targetIndex, project: self.id), artifact: .executable(.executable))

    try await self.withExecutable(targetIndex) { (target: borrowing AnyExecutable) in
      try await target.run(projectBuildDir: self.buildDir(context), args: args)
    }
  }

  public func buildStatements(context: Beaver) async throws -> BuildBackendBuilder {
    var stmts = BuildBackendBuilder()
    try await self.defaultBuildStatements(in: &stmts, context: context)
    return stmts
  }

  func defaultBuildStatements(in stmts: inout BuildBackendBuilder, context: Beaver) async throws {
    var commands = [String]()
    let contextPtr = withUnsafePointer(to: context) { $0 }
    let projectPointer = withUnsafePointer(to: self) { $0 }
    try await self.loopTargets { target in
      stmts.join(try await target.buildStatements(inProject: projectPointer.pointee, context: contextPtr.pointee))
      commands.append("\(projectPointer.pointee.name)$:\(target.name)")
    }
    stmts.addPhonyCommand(
      name: self.name,
      commands: commands
    )
  }

  //func build(context: borrowing Beaver) async throws {
  //  try await context.ninja(self.name)
  //}

  //func build(
  //  _ targetRef: TargetRef.Ref,
  //  context: borrowing Beaver
  //) async throws {
  //  try await context.ninja("\(self.name):\(try await self.targetName(targetRef))")
  //}

  //func build(
  //  _ targetRef: TargetRef.Ref,
  //  artifact: ArtifactType,
  //  context: borrowing Beaver
  //) async throws {
  //  try await context.ninja("\(self.name):\(try await self.targetName(targetRef)):\(artifact)")
  //}
}
