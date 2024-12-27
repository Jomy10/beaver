/// A sendable, non-copyable array
public struct NonCopyableArray<Element: ~Copyable>: ~Copyable {
  var buffer: UnsafeMutableBufferPointer<Element>
  public private(set) var count: Int = 0

  public init(withCapacity capacity: Int = 10) {
    self.buffer = UnsafeMutableBufferPointer.allocate(capacity: capacity)
    self.count = 0
  }

  public consuming func appending(_ element: consuming Element) -> Self {
    self.append(element)
    return self
  }

  public mutating func append(_ element: consuming Element) {
    if self.count >= self.buffer.count {
      self.buffer = self.buffer.reallocate(capacity: buffer.count * 2)
    }

    self.buffer.initializeElement(at: self.count, to: element)
    self.count += 1
  }

  public func firstIndex(where fn: (borrowing Element) throws -> Bool) rethrows -> Int? {
    for index in self.indices {
      //let rawPtr = self.buffer[index]
      //let ptr = rawPtr.assumingMemoryBound(to: Element.self)
      if (try fn(self.buffer[index])) {
        return index
      }
    }
    return nil
  }

  public func withElement<Result>(_ idx: Int, _ cb: (borrowing Element) throws -> Result) rethrows -> Result {
    if idx < self.count {
      return try cb(self.buffer[idx])
    } else {
      fatalError("Index out of range")
    }
  }

  public func withElement<Result>(_ idx: Int, _ cb: (borrowing Element) async throws -> Result) async rethrows -> Result {
    if idx < self.count {
      return try await cb(self.buffer[idx])
    } else {
      fatalError("Index out of range")
    }
  }

  public mutating func mutatingElement<Result>(_ idx: Int, _ cb: (inout Element) throws -> Result) rethrows -> Result {
    if idx < self.count {
      return try cb(&self.buffer[idx])
    } else {
      fatalError("Index out of range")
    }
  }

  public mutating func mutatingElement<Result>(_ idx: Int, _ cb: (inout Element) async throws -> Result) async rethrows -> Result {
    if idx < self.count {
      return try await cb(&self.buffer[idx])
    } else {
      fatalError("Index out of range")
    }
  }

  public mutating func popFirst() throws -> Element? {
    if self.count == 0 { return nil }
    self.count -= 1
    return self.buffer.moveElement(from: self.count)
  }

  public func forEach(_ cb: (borrowing Element) throws -> Void) rethrows {
    for i in self.indices {
      try self.withElement(i, cb)
    }
  }

  public func forEach(_ cb: (borrowing Element) async throws -> Void) async rethrows {
    for i in self.indices {
      try await self.withElement(i, cb)
    }
  }

  public var startIndex: Int { 0 }
  public var endIndex: Int { self.count }
  public var indices: Range<Int> { 0..<self.endIndex }

  deinit {
    self.buffer.deallocate()
  }
}

extension UnsafeMutableBufferPointer where Element: ~Copyable {
  func reallocate(capacity: Int) -> UnsafeMutableBufferPointer<Element> {
    let newPtr = UnsafeMutableBufferPointer.allocate(capacity: capacity)
    _ = newPtr.moveInitialize(fromContentsOf: self)
    self.deallocate()
    return newPtr
  }
}
