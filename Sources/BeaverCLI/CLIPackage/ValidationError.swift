public struct ValidationError: Error {
  let message: String

  public init(_ message: String) {
    self.message = message
  }

  public static func notConvertible(argument: String, to type: Any.Type) -> Self {
    return self.init("\(type) cannot be represented by \(argument)")
  }
}
