public final class Rc<T: ~Copyable> {
  private var inner: T?

  public init(_ value: consuming T) {
    self.inner = consume value
  }

  private init() {
    self.inner = nil
  }

  public static func uninitialized() -> Self {
    self.init()
  }

  public func initialize(_ value: consuming T) {
    self.inner = consume value
  }

  public func withInner<ResultType: ~Copyable>(_ cb: (borrowing T) throws -> ResultType) rethrows -> ResultType {
    try cb(self.inner!)
  }

  public func withInner<ResultType: ~Copyable>(_ cb: (inout T) throws -> ResultType) rethrows -> ResultType {
    try cb(&self.inner!)
  }

  public func withInner<ResultType: ~Copyable>(_ cb: (borrowing T) async throws -> ResultType) async rethrows -> ResultType {
    try await cb(self.inner!)
  }

  public func withInner<ResultType: ~Copyable>(_ cb: (inout T) async throws -> ResultType) async rethrows -> ResultType {
    try await cb(&self.inner!)
  }

  public func value() -> T where T: Copyable {
    self.inner!
  }

  struct NoValue: Error {}

  public func tryWithInner<ResultType>(_ cb: (borrowing T) throws -> ResultType) throws -> ResultType {
    if self.inner == nil { throw NoValue() }
    return try cb(self.inner!)
  }

  public func tryWithInner<ResultType>(_ cb: (inout T) throws -> ResultType) throws -> ResultType {
    if self.inner == nil { throw NoValue() }
    return try cb(&self.inner!)
  }

  public func tryWithInner<ResultType>(_ cb: (borrowing T) async throws -> ResultType) async throws -> ResultType {
    if self.inner == nil { throw NoValue() }
    return try await cb(self.inner!)
  }

  public func tryWithInner<ResultType>(_ cb: (inout T) async throws -> ResultType) async throws -> ResultType {
    if self.inner == nil { throw NoValue() }
    return try await cb(&self.inner!)
  }

  public func tryValue() -> T? where T: Copyable {
    self.inner
  }

  public func take() -> T? {
    self.inner.take()
  }
}
