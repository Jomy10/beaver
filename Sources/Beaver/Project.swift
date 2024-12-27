import Foundation

public struct Project: ~Copyable, Sendable {
  public let name: String
  public var baseDir: URL
  public var buildDir: URL
  public var targets: AsyncRWLock<NonCopyableArray<any Target>>

  public init(
    name: String,
    baseDir: URL = URL.currentDirectory(),
    buildDir: URL = URL.currentDirectory().appending(path: ".build"),
    targets: consuming NonCopyableArray<any Target> = NonCopyableArray()
  ) {
    self.name = name
    self.baseDir = baseDir
    self.buildDir = buildDir
    self.targets = AsyncRWLock(targets)
  }

  enum TargetAccessError: Error {
    case noTarget(named: String)
    case noLibrary(named: String)
  }

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
      //if !(targets.buffer[index] is (any Library).Type) {
      //  throw TargetAccessError.noLibrary(named: targetName)
      //}
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
}

public typealias ProjectRef = Int
