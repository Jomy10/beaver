import Foundation
import Utils
//import AsyncAlgorithms

public struct BeaverProject: Project, CommandCapableProject, MutableProject, ~Copyable, Sendable {
  public var id: Int = -1
  //public var id: Int {
  //  get { self._id }
  //  set async {
  //    self._id = newValue
  //    await self.targets.write { targets in
  //      for targetIndex in 0..<targets.count {
  //        targets.withElement { (target: inout AnyTarget) in
  //          target.projectId = newValue
  //        }
  //      }
  //    }
  //  }
  //}
  public let name: String
  public var baseDir: URL
//  public var buildDir: URL
  public var targets: AsyncRWLock<NonCopyableArray<AnyTarget>>

  var commands: Commands

  public init(
    name: String,
    baseDir: URL = URL.currentDirectory(),
    //buildDir: URL?,
    targets: consuming NonCopyableArray<AnyTarget> = NonCopyableArray(),
    context: inout Beaver
  ) throws {
//    try context.requireBuildDir()
    self.name = name
    self.baseDir = baseDir
//    self.buildDir = context.buildDir(for: name)
    self.targets = AsyncRWLock(targets)
    self.commands = Commands()
  }

  public var targetRefs: [TargetRef] {
    get async {
      await self.targets.read { targets in
        await targets.map { target in TargetRef(target: target.id, project: self.id) }
      }
    }
  }

  @discardableResult
  public mutating func addTarget(_ target: consuming AnyTarget) async -> TargetRef {
    var target: (AnyTarget)? = target
    let id = await self.targets.write { (targets: inout NonCopyableArray<AnyTarget>) in
      let id = targets.count
      var target = target.take()!
      target.id = id
      target.projectId = self.id
      targets.append(target)
      return id
    }
    return TargetRef(target: id, project: self.id)
  }

//  public func clean(context: borrowing Beaver) async throws {
//    try await self.targets.read { targets in
//      try await targets.forEach { target in
//        try await target.clean(projectBuildDir: context.buildDir(for: self.name), context: context)
//      }
//    }
//  }

  //public func build(targetIndex: Int, context: borrowing Beaver) async throws {
  //  self.withTarget(targetIndex) { (target: borrowing any Target)
  //    try await target.build()
  //  }
  //}

  // Retrieval by index //

  public func withTarget<Result>(_ index: TargetRef.Ref, _ cb: (borrowing AnyTarget) async throws -> Result) async rethrows -> Result {
    try await self.targets.read { targets in
      try await cb(targets.buffer[index])
    }
  }

  public mutating func withTarget<Result>(_ index: TargetRef.Ref, _ cb: (inout AnyTarget) async throws -> Result) async rethrows -> Result {
    try await self.targets.write { targets in
      try await cb(&targets.buffer[index])
    }
  }

  public func withLibrary<Result>(_ index: TargetRef.Ref, _ cb: (borrowing AnyLibrary) async throws -> Result) async throws -> Result {
    try await self.targets.read { targets in
      switch (targets.buffer[index]) {
        case .library(let lib):
          try await cb(lib)
        default:
          throw TargetAccessError.notALibrary(named: targets.buffer[index].name)
      }
    }
  }

  public func withExecutable<Result>(_ index: TargetRef.Ref, _ cb: (borrowing AnyExecutable) async throws -> Result) async throws -> Result {
    try await self.targets.read { targets in
      switch (targets.buffer[index]) {
        case .executable(let lib):
          try await cb(lib)
        default:
          throw TargetAccessError.notAnExecutable(named: targets.buffer[index].name)
      }
    }
  }

  public func loopTargets<Result>(_ cb: (borrowing AnyTarget) async throws -> Result) async rethrows -> [Result] {
    var res = [Result]()
    try await self.targets.read { targets in
      try await targets.forEach { (target: borrowing AnyTarget) in
        res.append(try await cb(target))
      }
    }
    return res
  }

  //public func withTargetPointer<Result>(_ index: Int, _ cb: (UnsafePointer<any Target>) async throws -> Result) async rethrows -> Result {
  //  return try await self.targets.read { targets in
  //    let targetPointer = withUnsafePointer(to: targets.buffer[index]) { $0 }
  //    return try await cb(targetPointer)
  //  }
  //}

  // Retrieve data //

  public func targetIndex(name: String) async -> Int? {
    await self.targets.read { targets in
      targets.firstIndex { $0.name == name }
    }
  }

  public func targetName(_ index: Int) async -> String {
    await self.targets.read { targets in
      targets.buffer[index].name
    }
  }

  // Commands //

  public func addCommand(
    _ name: String,
    overwrite: Bool = false,
    _ execute: @escaping Commands.Command
  ) async throws {
    try await self.commands.addCommand(name: name, overwrite: overwrite, execute: execute)
  }

  public func call(_ commandName: String, context: borrowing Beaver) async throws {
    try await self.commands.call(commandName, context: context)
  }

  public func callDefault(context: borrowing Beaver) async throws {
    try await self.commands.callDefault(context: context)
  }

  public func isOverwritten(_ commandName: String) async -> Bool {
    await self.commands.overwrites.contains(commandName)
  }

  public func hasCommand(_ commandName: String) async -> Bool {
    await self.commands.commands.keys.contains(commandName)
  }

  public func hasCommands() async -> Bool {
    await self.commands.commands.count > 0
  }

  // Build //

  //public func build(context: borrowing Beaver) async throws {
  //  try await context.ninja(self.name)
  //  //try await Tools.exec(
  //  //  Tools.ninja!,
  //  //  [
  //  //    "-f",
  //  //    context.buildDir.appending(path: "build.\(context.optimizeMode).ninja"),
  //  //    self.name
  //  //  ]
  //  //)

  //  //try await self.targets.read { targets in
  //  //  for targetIndex in (0..<targets.count) {
  //  //    let builder = try await TargetBuilder(
  //  //      target: TargetRef(target: targetIndex, project: self.id),
  //  //      artifact: nil,
  //  //      context: context
  //  //    )
  //  //    if (await builder.build(context: context)) {
  //  //      throw Beaver.BuildError.buildError
  //  //    }
  //  //  }
  //  //}
  //}

  //public func build(_ targetIndex: TargetRef.Ref, context: borrowing Beaver) async throws {
  //  try await self.withTarget(targetIndex) { (target: borrowing AnyTarget) in
  //    try await target.build(context: context)
  //  }
  //  //let builder = try await TargetBuilder(
  //  //  target: TargetRef(target: targetIndex, project: self.id),
  //  //  artifact: nil,
  //  //  context: context
  //  //)
  //  //if (await builder.build(context: context)) {
  //  //  throw Beaver.BuildError.buildError
  //  //}
  //}

  //public func build(_ targetIndex: TargetRef.Ref, artifact: ArtifactType, context: borrowing Beaver) async throws {
  //  try await self.withTarget(targetIndex) { (target: borrowing Target)
  //    try await target.build(artifact: artifact, context: context)
  //  }
  //  //let builder = try await TargetBuilder(
  //  //  target: TargetRef(target: targetIndex, project: self.id),
  //  //  artifact: artifact,
  //  //  context: context
  //  //)
  //  //if (await builder.build(context: context)) {
  //  //  throw Beaver.BuildError.buildError
  //  //}
  //}

  public func getOnlyExecutable() async throws -> Int {
    try await self.targets.read { targets in
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
  }

  public func targetNames() async -> [String] {
    await self.targets.read { targets in
      await targets.map { $0.name }
    }
  }
}
