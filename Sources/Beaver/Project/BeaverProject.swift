import Foundation
import Utils
import AsyncAlgorithms

public struct BeaverProject: Project, CommandCapableProject, MutableProject, ~Copyable, Sendable {
  public var id: Int = -1
  public let name: String
  public var baseDir: URL
  public var buildDir: URL
  public var targets: AsyncRWLock<NonCopyableArray<AnyTarget>>

  var commands: Commands

  public init(
    name: String,
    baseDir: URL = URL.currentDirectory(),
    buildDir: URL = URL.currentDirectory().appending(path: ".build"),
    targets: consuming NonCopyableArray<AnyTarget> = NonCopyableArray(),
    context: borrowing Beaver
  ) {
    self.name = name
    self.baseDir = baseDir
    self.buildDir = buildDir.appending(path: context.optimizeMode.rawValue)
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

  public func clean(context: borrowing Beaver) async throws {
    try await self.targets.read { targets in
      try await targets.forEach { target in
        try await target.clean(projectBuildDir: self.buildDir, context: context)
      }
    }
  }

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

  public func loopTargets(_ cb: (borrowing AnyTarget) async throws -> Void) async rethrows {
    try await self.targets.read { targets in
      try await targets.forEach { (target: borrowing AnyTarget) in
        try await cb(target)
      }
    }
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

  public func targetName(_ index: Int) async -> String? {
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

  // Build //

  public func build(context: borrowing Beaver) async throws {
    try await self.targets.read { targets in
      for targetIndex in (0..<targets.count) {
        let builder = try await TargetBuilder(
          target: TargetRef(target: targetIndex, project: self.id),
          artifact: nil,
          context: context
        )
        await builder.build(context: context)
      }
    }
  }

  public func build(_ targetIndex: TargetRef.Ref, context: borrowing Beaver) async throws {
    let builder = try await TargetBuilder(
      target: TargetRef(target: targetIndex, project: self.id),
      artifact: nil,
      context: context
    )
    await builder.build(context: context)
    //try await self.withTarget(targetIndex) { (target: borrowing AnyTarget) in
    //  try await target.asProtocol { try await $0.build(
    //    projectBaseDir: self.baseDir,
    //    projectBuildDir: self.buildDir,
    //    context: context
    //  )}
    //}
  }

  public func build(_ targetIndex: TargetRef.Ref, artifact: ArtifactType, context: borrowing Beaver) async throws {
    let builder = try await TargetBuilder(
      target: TargetRef(target: targetIndex, project: self.id),
      artifact: artifact,
      context: context
    )
    await builder.build(context: context)
    //try await self.withTarget(targetIndex) { (target: borrowing any Target) in
    //  try await target.asProtocol { try await $0.build(
    //    artifact: artifact,
    //    projectBaseDir: self.baseDir,
    //    projectBuildDir: self.buildDir,
    //    context: context
    //  )}
    //}
  }

  public func run(args: [String]) async throws {
    let targetRef = try await self.targets.read { targets in
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

    try await self.withExecutable(targetRef) { (target: borrowing AnyExecutable) in
      try await target.run(projectBuildDir: self.buildDir, args: args)
    }
  }
}
