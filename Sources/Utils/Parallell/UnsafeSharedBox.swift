public final class UnsafeSharedBox<T>: @unchecked Sendable {
  public var value: T

  public init(_ value: T) {
    self.value = value
  }
}
