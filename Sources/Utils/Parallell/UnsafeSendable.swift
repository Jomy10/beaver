public struct UnsafeSendable<T>: @unchecked Sendable {
  public let value: T

  public init(_ value: T) {
    self.value = value
  }
}
