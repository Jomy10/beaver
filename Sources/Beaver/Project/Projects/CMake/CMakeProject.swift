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
  public var buildDir: URL

  private var targets: NonCopyableArray<AnyTarget>

  public init(
    name: String,
    baseDir: URL,
    buildDir: URL? = nil,
    targets: consuming NonCopyableArray<AnyTarget>
  ) {
    self.name = name
    self.baseDir = baseDir
    self.buildDir = buildDir ?? baseDir.appending(path: ".build")
    self.targets = targets
  }

  public func clean(context: borrowing Beaver) async throws {
    if FileManager.default.exists(at: self.buildDir) {
      try FileManager.default.removeItem(at: self.buildDir)
    }
  }

  public func build(context: borrowing Beaver) async throws {
    try await Tools.exec(
      Tools.make!,
      ["-j", "4"],
      baseDir: buildDir,
      context: self.name
    )
  }

  public func build(
    _ targetRef: TargetRef.Ref,
    artifact: ArtifactType,
    context: borrowing Beaver
  ) async throws {
    let targetName = await self.targetName(targetRef)!
    try await Tools.exec(
      Tools.make!,
      ["-j", "-4", targetName],
      baseDir: buildDir,
      context: self.name + ":\(targetName)"
    )
  }

  public func build(
    _ targetRef: TargetRef.Ref,
    context: borrowing Beaver
  ) async throws {
    let targetName = await self.targetName(targetRef)!
    try await Tools.exec(
      Tools.make!,
      ["-j", "4", targetName],
      baseDir: buildDir,
      context: self.name + ":\(targetName)"
    )
  }

  public func run(args: [String]) async throws {
    throw CMakeError.cannotRun
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

  public func loopTargets(_ cb: (borrowing AnyTarget) async throws -> Void) async rethrows {
    try await self.targets.forEach(cb)
  }

  public func targetIndex(name: String) async -> Int? {
    self.targets.firstIndex(where: { $0.name == name })
  }

  public func targetName(_ index: Int) async -> String? {
    self.targets.withElement(index) { $0.name }
  }

  public func targetNames() async -> [String] {
    await self.targets.map { $0.name }
  }
}
