public struct Flags: Sendable {
  public var `public`: [String]
  public var `private`: [String]

  public init() {
    self.public = []
    self.private = []
  }

  public init(
    `public`: [String] = [],
    `private`: [String] = []
  ) {
    self.public = `public`
    self.private = `private`
  }
}

extension Flags: ExpressibleByArrayLiteral {
  public typealias ArrayLiteralElement = String

  public init(arrayLiteral: ArrayLiteralElement...) {
    self.public = arrayLiteral
    self.private = []
  }
}
