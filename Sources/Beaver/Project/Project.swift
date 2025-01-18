import Foundation
import Utils

public struct Project: ~Copyable, Sendable {
  public var id: Int = -1
  public let name: String
  public var baseDir: URL
  public var buildDir: URL
  public var targets: AsyncRWLock<NonCopyableArray<any Target>>

  var commands: Commands

  public init(
    name: String,
    baseDir: URL = URL.currentDirectory(),
    buildDir: URL = URL.currentDirectory().appending(path: ".build"),
    targets: consuming NonCopyableArray<any Target> = NonCopyableArray(),
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
  public mutating func addTarget(_ target: consuming any Target) async -> TargetRef {
    var target: (any Target)? = target
    let id = await self.targets.write { (targets: inout NonCopyableArray<any Target>) in
      let id = targets.count
      var target = target.take()!
      target.id = id
      target.projectId = self.id
      targets.append(target)
      return id
    }
    return TargetRef(target: id, project: self.id)
  }

  enum TargetAccessError: Error {
    /// The target doesn't exist
    case noTarget(named: String)
    /// The target exists, but is not a library
    case notALibrary(named: String)
    /// The target exists, but is not an executable
    case notAnExecutable(named: String)
  }

  public func clean(context: borrowing Beaver) async throws {
    try await self.targets.read { targets in
      try await targets.forEach { target in
        try await target.clean(projectBuildDir: self.buildDir, context: context)
      }
    }
  }

  // Retrieval by index //

  public func withTarget<Result>(_ index: Int, _ cb: (borrowing any Target) async throws -> Result) async rethrows -> Result {
    try await self.targets.read { targets in
      try await cb(targets.buffer[index])
    }
  }

  public mutating func withTarget<Result>(_ index: Int, _ cb: (inout any Target) async throws -> Result) async rethrows -> Result {
    try await self.targets.write { targets in
      try await cb(&targets.buffer[index])
    }
  }

  public func withLibrary<Result>(_ index: Int, _ cb: (borrowing any Library) async throws -> Result) async throws -> Result {
    try await self.targets.read { targets in
      if targets.buffer[index] is any Library {
        try await cb(targets.buffer[index] as! any Library)
      } else {
        throw TargetAccessError.notALibrary(named: targets.buffer[index].name)
      }
    }
  }

  public func withExecutable<Result>(_ index: Int, cb: (borrowing any Executable) async throws -> Result) async throws -> Result {
    try await self.targets.read { targets in
      if targets.buffer[index] is any Executable {
        try await cb(targets.buffer[index] as! any Executable)
      } else {
        throw TargetAccessError.notAnExecutable(named: targets.buffer[index].name)
      }
    }
  }

  public func withTargetPointer<Result>(_ index: Int, _ cb: (UnsafePointer<any Target>) async throws -> Result) async rethrows -> Result {
    return try await self.targets.read { targets in
      let targetPointer = withUnsafePointer(to: targets.buffer[index]) { $0 }
      return try await cb(targetPointer)
    }
  }

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
}
