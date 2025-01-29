public final class UnsafeSharedBox<T: ~Copyable>: @unchecked Sendable {
  public var value: T

  public init(_ value: consuming T) {
    self.value = value
  }
}
