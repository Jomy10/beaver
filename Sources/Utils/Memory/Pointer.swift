extension UnsafeMutableBufferPointer where Element: ~Copyable {
  public func reallocate(capacity: Int) -> UnsafeMutableBufferPointer<Element> {
    let newPtr = UnsafeMutableBufferPointer.allocate(capacity: capacity)
    _ = newPtr.moveInitialize(fromContentsOf: self)
    self.deallocate()
    return newPtr
  }
}

extension UnsafeMutableBufferPointer {
  public func reallocate(capacity: Int, initializingWith zero: Element) -> UnsafeMutableBufferPointer<Element> {
    let newPtr = UnsafeMutableBufferPointer.allocate(capacity: capacity)
    let initializeFromIndex = newPtr.moveInitialize(fromContentsOf: self)
    for i in initializeFromIndex..<newPtr.count {
      newPtr.initializeElement(at: i, to: zero)
    }
    self.deallocate()
    return newPtr
  }
}
