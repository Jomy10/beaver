import Foundation

public struct Project: ~Copyable, Sendable {
  public var id: Int = -1
  public let name: String
  public var baseDir: URL
  public var buildDir: URL
  public var targets: AsyncRWLock<NonCopyableArray<any Target>>

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
    case noTarget(named: String)
    case noLibrary(named: String)
  }

  // retrieval by name //

  public mutating func withTarget<Result>(named targetName: String, _ cb: (inout any Target) async throws -> Result) async throws -> Result {
    return try await self.targets.write { targets in
      guard let index = targets.firstIndex(where: { target in target.name == targetName }) else {
        throw TargetAccessError.noTarget(named: targetName)
      }
      return try await targets.mutatingElement(index, cb)
    }
  }

  public func withTarget<Result>(named targetName: String, _ cb: (borrowing any Target) async throws -> Result) async throws -> Result {
    return try await self.targets.read { targets in
      guard let index = targets.firstIndex(where: { target in target.name == targetName }) else {
        throw TargetAccessError.noTarget(named: targetName)
      }
      return try await targets.withElement(index, cb)
    }
  }

  public func withLibrary<Result>(named targetName: String, _ cb: (borrowing any Library) async throws -> Result) async throws -> Result {
    return try await self.targets.read { targets in
      guard let index = targets.firstIndex(where: { target in target.name == targetName }) else {
        throw TargetAccessError.noTarget(named: targetName)
      }
      return try await cb(targets.buffer[index] as! any Library)
    }
  }

  public func withExecutable<Result>(named targetName: String, _ cb: (borrowing any Executable) async throws -> Result) async throws -> Result {
    return try await self.targets.read { targets in
      guard let index = targets.firstIndex(where: { target in target.name == targetName }) else {
        throw TargetAccessError.noTarget(named: targetName)
      }
      return try await cb(targets.buffer[index] as! any Executable)
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

  public func withLibrary<Result>(_ index: Int, _ cb: (borrowing any Library) async throws -> Result) async rethrows -> Result {
    try await self.targets.read { targets in
      try await cb(targets.buffer[index] as! any Library)
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
}
