import Utils

final class PersistedStorage<Key: Hashable>: Sendable {
  private let storage: AsyncRWLock<[Key:(Any.Type, UnsafeMutableRawPointer)]>

  init() throws {
    self.storage = AsyncRWLock([:])
  }

  func store<T>(value: consuming T, key: Key) async {
    let storage = UnsafeMutablePointer<T>.allocate(capacity: 1)
    storage.pointee = value
    await self.store(ptr: storage, key: key)
  }

  func store<T>(ptr: UnsafeMutablePointer<T>, key: Key) async {
    await self.storage.write { storage in
      Self.store(ptr: ptr, key: key, storage: &storage)
    }
  }

  static func store<T>(ptr: UnsafeMutablePointer<T>, key: Key, storage: inout [Key: (any Any.Type, UnsafeMutableRawPointer)]) {
    _ = storage[key]?.1.assumingMemoryBound(to: T.self)
    let type: Any.Type = T.self
    storage[key] = (type, UnsafeMutableRawPointer(ptr))
  }

  func storing<T>(key: Key, _ initialize: @autoclosure () async throws -> T) async rethrows -> T {
    return try await self.storage.write { storage in
      let value = try await initialize()
      let ptr = UnsafeMutablePointer<T>.allocate(capacity: 1)
      ptr.pointee = value
      Self.store(ptr: ptr, key: key, storage: &storage)
      return value
    }
  }

  func storing<T>(key: Key, _ initialize: @autoclosure () async throws -> T) async rethrows {
    try await self.storage.write { storage in
      let value = try await initialize()
      let ptr = UnsafeMutablePointer<T>.allocate(capacity: 1)
      ptr.pointee = value
      Self.store(ptr: ptr, key: key, storage: &storage)
    }
  }

  func storingOrRetrieving<T>(key: Key, _ initialize: @autoclosure () async throws -> T) async throws -> T {
    if let element: T = try await self.getElement(withKey: key) {
      return element
    } else {
      return try await self.storing(key: key, try await initialize())
    }
  }

  func clear(forKey key: Key) async {
    await self.storage.write { (storage: inout [Key: (Any.Type, UnsafeMutableRawPointer)]) in
      guard let value: (Any.Type, UnsafeMutableRawPointer) = storage[key] else { return }
      value.1.deallocate()
    }
  }


  func clearAll() async {
    await self.storage.write { storage in
      for (k, _) in storage {
        await self.clear(forKey: k)
      }
    }
  }

  enum RetrievalError: Error {
    case elementDoesntExist
    case elementIsNotOfRequestedType(expected: Any.Type, got: Any.Type)
  }

  func hasElement(key: Key) async -> Bool {
    await self.storage.read { storage in
     storage[key] != nil
    }
  }

  func withElement<Result, T>(withKey key: Key, _ cb: (inout T) async throws -> Result) async throws -> Result {
    return try await self.storage.read { storage in
      if let (type, ptr): (Any.Type, UnsafeMutableRawPointer) = storage[key] {
        if type != (T.self as Any.Type) {
          throw RetrievalError.elementIsNotOfRequestedType(expected: T.self, got: type)
        }
        return try await cb(&ptr.assumingMemoryBound(to: T.self).pointee)
      } else {
        throw RetrievalError.elementDoesntExist
      }
    }
  }

  func getElement<T>(withKey key: Key) async throws -> T? {
    return try await self.storage.read { storage in
      if let (type, ptr) = storage[key] {
        if type != (T.self as Any.Type) {
          throw RetrievalError.elementIsNotOfRequestedType(expected: T.self, got: type)
        }
        return ptr.assumingMemoryBound(to: T.self).pointee
      } else {
        return nil
      }
    }
  }

  deinit {
    self.storage.unsafeInner { storage in
      for (_, v) in storage {
        v.1.deallocate()
      }
    }
  }
}
