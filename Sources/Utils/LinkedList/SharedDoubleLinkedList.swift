public actor SharedDoublyLinkedList<T: Sendable>: Sendable {
  @usableFromInline
  var list: DoublyLinkedList<T> = DoublyLinkedList()

  @inlinable
  @discardableResult
  public func pushEnd(_ value: T) -> Int {
    self.list.pushEnd(value)
  }

  @inlinable
  public func popEnd() -> T? {
    self.list.popEnd()
  }

  @inlinable
  @discardableResult
  public func remove(at index: Int) -> T? {
    self.list.remove(at: index)
  }

  @inlinable
  public func forEach(_ cb: (borrowing T) throws -> Void) rethrows {
    try self.list.forEach(cb)
  }

  @inlinable
  public func forEach(_ cb: @Sendable (borrowing T) async throws -> Void) async rethrows {
    try await self.list.forEach(cb)
  }
}
