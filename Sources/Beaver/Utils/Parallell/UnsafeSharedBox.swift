final class UnsafeSharedBox<T>: @unchecked Sendable {
  var value: T

  init(_ value: T) {
    self.value = value
  }
}
