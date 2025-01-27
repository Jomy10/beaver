public struct UnsafeSendable<T>: @unchecked Sendable {
  public let value: T

  @inlinable
  public init(_ value: T) {
    self.value = value
  }
}
