/// An array that cannot be copied and can contain non-copyable elements
public struct NonCopyableArray<Element: ~Copyable>: ~Copyable {
  public var buffer: UnsafeMutableBufferPointer<Element>

  @usableFromInline
  internal var __count: Int = 0
  @inlinable
  public private(set) var count: Int {
    get { self.__count }
    set { self.__count = newValue }
  }

  @inlinable
  public init(withCapacity capacity: Int = 10) {
    self.buffer = UnsafeMutableBufferPointer.allocate(capacity: capacity)
    self.count = 0
  }

  @inlinable
  public consuming func appending(_ element: consuming Element) -> Self {
    self.append(element)
    return self
  }

  @inlinable
  public mutating func append(_ element: consuming Element) {
    if self.count >= self.buffer.count {
      self.buffer = self.buffer.reallocate(capacity: buffer.count * 2)
    }

    self.buffer.initializeElement(at: self.count, to: element)
    self.count += 1
  }

  @inlinable
  public func firstIndex(where fn: (borrowing Element) throws -> Bool) rethrows -> Int? {
    for index in self.indices {
      if (try fn(self.buffer[index])) {
        return index
      }
    }
    return nil
  }

  @inlinable
  public func allIndexes(where fn: (borrowing Element) throws -> Bool) rethrows -> [Int] {
    var indexes: [Int] = []
    for index in self.indices {
      if (try fn(self.buffer[index])) {
        indexes.append(index)
      }
    }
    return indexes
  }

  @inlinable
  public func withElement<Result>(_ idx: Int, _ cb: (borrowing Element) throws -> Result) rethrows -> Result {
    if idx < self.count {
      return try cb(self.buffer[idx])
    } else {
      fatalError("Index out of range")
    }
  }

  @inlinable
  public func withElement<Result>(_ idx: Int, _ cb: (borrowing Element) async throws -> Result) async rethrows -> Result {
    if idx < self.count {
      return try await cb(self.buffer[idx])
    } else {
      fatalError("Index out of range")
    }
  }

  @inlinable
  public mutating func mutatingElement<Result>(_ idx: Int, _ cb: (inout Element) throws -> Result) rethrows -> Result {
    if idx < self.count {
      return try cb(&self.buffer[idx])
    } else {
      fatalError("Index out of range")
    }
  }

  @inlinable
  public mutating func mutatingElement<Result>(_ idx: Int, _ cb: (inout Element) async throws -> Result) async rethrows -> Result {
    if idx < self.count {
      return try await cb(&self.buffer[idx])
    } else {
      fatalError("Index out of range")
    }
  }

  @inlinable
  public mutating func popFirst() throws -> Element? {
    if self.count == 0 { return nil }
    self.count -= 1
    return self.buffer.moveElement(from: self.count)
  }

  @inlinable
  public func forEach(_ cb: (borrowing Element) throws -> Void) rethrows {
    for i in self.indices {
      try self.withElement(i, cb)
    }
  }

  @inlinable
  public func forEach(_ cb: (borrowing Element) async throws -> Void) async rethrows {
    for i in self.indices {
      try await self.withElement(i, cb)
    }
  }

  @inlinable
  public func forEachUntil(_ cb: (borrowing Element) async throws -> Bool) async rethrows {
    for i in self.indices {
      if (try await self.withElement(i, cb)) {
        return
      }
    }
  }

  @inlinable
  public func map<Result>(_ cb: (borrowing Element) async throws -> Result) async rethrows -> [Result] {
    var res: [Result] = []
    for i in self.indices {
      await res.append(try self.withElement(i, cb))
    }
    return res
  }

  @inlinable
  public var startIndex: Int { 0 }
  @inlinable
  public var endIndex: Int { self.count }
  @inlinable
  public var indices: Range<Int> { 0..<self.endIndex }

  deinit {
    self.buffer.deallocate()
  }
}
