import Foundation
import Utils

public struct CMakeProject: Project, ~Copyable, @unchecked Sendable {
  private var _id: Int = -1
  public var id: Int {
    get { self._id }
    set {
      self._id = newValue
      for targetIndex in 0..<self.targets.count {
        self.targets.mutatingElement(targetIndex) { (target: inout AnyTarget) in
          target.projectId = newValue
        }
      }
    }
  }
  public let name: String
  public var baseDir: URL
  /// includes /debug or /release
  public var buildDir: URL
  public var makeFlags: [String]

  private var targets: NonCopyableArray<AnyTarget>

  public init(
    name: String,
    baseDir: URL,
    buildDir: URL,
    makeFlags: [String],
    targets: consuming NonCopyableArray<AnyTarget>
  ) {
    self.name = name
    self.baseDir = baseDir
    self.buildDir = buildDir
    self.targets = targets
    self.makeFlags = makeFlags
  }

  public func buildDir(_ context: borrowing Beaver) -> URL {
    self.buildDir
  }

  // TODO: find a better way than just calling ninja from ninja
  public func buildStatements(context: borrowing Beaver) async throws -> BuildBackendBuilder {
    var stmts = BuildBackendBuilder()

    var commands = [String]()
    let contextPtr = withUnsafePointer(to: context) { $0 }
    let projectPointer = withUnsafePointer(to: self) { $0 }
    _ = try await self.loopTargets { target in
      stmts.join(try await target.buildStatements(inProject: projectPointer.pointee, context: contextPtr.pointee))
      commands.append("\(projectPointer.pointee.name)$:\(target.name)")
    }

    //stmts.add("subninja \(.appending(path: "build.ninja").ninjaPath)")
    stmts.addNinjaCommand(
      name: self.name,
      baseDir: self.buildDir(context),
      filename: "build.ninja",
      targets: nil // all
    )
    return stmts
  }

  /// Build the specified target from the ninja file
  public func build(_ target: borrowing AnyTarget, context: borrowing Beaver) async throws {
    let ninja = try NinjaRunner(buildFile: self.buildDir(context).appending(path: "build.ninja").path)
    try await ninja.build(targets: target.name, dir: self.buildDir(context).path)
  }

  public func getOnlyExecutable() async throws -> Int {
    var index: Int? = nil
    for targetIndex in targets.indices {
      switch (targets.buffer[targetIndex]) {
        case .executable(_):
          if index != nil {
            throw Beaver.RunError.moreExecutables
          }
          index = targetIndex
        default:
          continue
      }
    }

    if let index = index {
      return index
    } else {
      throw Beaver.RunError.noExecutables
    }
  }

  public func withTarget<Result>(_ ref: TargetRef.Ref, _ cb: (borrowing AnyTarget) async throws -> Result) async rethrows -> Result {
    try await self.targets.withElement(ref, cb)
  }

  public mutating func withTarget<Result>(_ ref: TargetRef.Ref, _ cb: (inout AnyTarget) async throws -> Result) async rethrows -> Result {
    try await self.targets.mutatingElement(ref, cb)
  }

  public func withLibrary<Result>(_ ref: TargetRef.Ref, _ cb: (borrowing AnyLibrary) async throws -> Result) async throws -> Result {
    try await self.withTarget(ref) { target in
      switch (target) {
        case .library(let lib): return try await cb(lib)
        default:
          throw TargetAccessError.notLibrary
      }
    }
  }

  public func withExecutable<Result>(_ ref: TargetRef.Ref, _ cb: (borrowing AnyExecutable) async throws -> Result) async throws -> Result {
    try await self.withTarget(ref) { target in
      switch (target) {
        case .executable(let exe): return try await cb(exe)
        default:
          throw TargetAccessError.notExecutable
      }
    }
  }

  public func loopTargets<Result>(_ cb: (borrowing AnyTarget) async throws -> Result) async rethrows -> [Result] {
    try await self.targets.map(cb)
  }

  public func loopTargetsUntil(_ cb: (borrowing AnyTarget) async throws -> Bool) async rethrows {
    try await self.targets.forEachUntil(cb)
  }

  public func targetIndex(name: String) async -> Int? {
    self.targets.firstIndex(where: { $0.name == name })
  }

  public func targetName(_ index: Int) async -> String {
    self.targets.withElement(index) { $0.name }
  }

  public func targetNames() async -> [String] {
    await self.targets.map { $0.name }
  }
}
