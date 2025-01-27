struct CMakeDependency: Codable {
  /// A string uniquely identifying the target on which this target
  /// depends. This matches the main id member of the other target.
  let id: String
  let backtrace: UInt?
}
