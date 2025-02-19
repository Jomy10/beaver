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
//  public var buildDir: URL
  public var makeFlags: [String]

  private var targets: NonCopyableArray<AnyTarget>

  public init(
    name: String,
    baseDir: URL,
//    buildDir: URL? = nil,
    makeFlags: [String],
    targets: consuming NonCopyableArray<AnyTarget>
  ) {
    self.name = name
    self.baseDir = baseDir
//    self.buildDir = buildDir ?? baseDir.appending(path: ".build")
    self.targets = targets
    self.makeFlags = makeFlags
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
      baseDir: context.buildDir(for: self.name),
      filename: "build.ninja",
      targets: nil // all
    )
    return stmts
  }

  /// Build the specified target from the ninja file
  public func build(_ target: borrowing AnyTarget, context: borrowing Beaver) async throws {
    let ninja = try NinjaRunner(buildFile: context.buildDir(for: self.name).appending(path: "build.ninja").path)
    try await ninja.build(targets: target.name, dir: context.buildDir(for: self.name).path)
  }

  //public func clean(context: borrowing Beaver) async throws {
  //  if FileManager.default.exists(at: self.buildDir) {
  //    try FileManager.default.removeItem(at: self.buildDir)
  //  }
  //}


  //public func build(context: borrowing Beaver) async throws {
  //  try await context.ninja(self.name)
  //  //try await Tools.exec(
  //  //  Tools.make!,
  //  //  ["-j", "4"] + self.makeFlags,
  //  //  baseDir: buildDir,
  //  //  context: self.name
  //  //)
  //}

  //public func build(
  //  _ targetRef: TargetRef.Ref,
  //  artifact: ArtifactType,
  //  context: borrowing Beaver
  //) async throws {
  //  let targetName = await self.targetName(targetRef)!
  //  try await Tools.exec(
  //    Tools.make!,
  //    ["-j", "4", targetName] + self.makeFlags,
  //    baseDir: buildDir,
  //    context: self.name + ":\(targetName)"
  //  )
  //}

  //public func build(
  //  _ targetRef: TargetRef.Ref,
  //  context: borrowing Beaver
  //) async throws {
  //  let targetName = await self.targetName(targetRef)!
  //  try await Tools.exec(
  //    Tools.make!,
  //    ["-j", "4", targetName] + self.makeFlags,
  //    baseDir: buildDir,
  //    context: self.name + ":\(targetName)"
  //  )
  //}

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
