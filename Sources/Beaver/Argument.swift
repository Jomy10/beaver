public struct RubyArgument: Sendable {
  public let name: String
  public let mandatory: Bool

  init(_ name: String, mandatory: Bool = false) {
    self.name = name
    self.mandatory = mandatory
  }
}
