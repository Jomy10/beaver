public struct FlagDecl: Sendable, ArgumentProtocol {
  public var fullName: String
  public var shortName: String?
  public var help: String?

  public static let rangeSize: Int = 1

  public init(fullName: String, shortName: String?, help: String?) {
    self.fullName = fullName
    self.shortName = shortName
    self.help = help
  }

  public struct Parsed: Sendable, ParsedArgumentProtocol {}

  public func getParsed<C: Collection>(in array: borrowing C, range: Range<Int>) throws -> Self.Parsed
  where C.Element == String,
        C.Index == Int
  {
    return Self.Parsed()
  }
}

@propertyWrapper
public struct Flag: Sendable {
  public var wrappedValue: Bool

  public init(
    wrappedValue: Bool,
    name: String,
    shortName: String? = nil,
    help: String? = nil,
    default: (() -> Bool)? = nil
  ) {
    self.wrappedValue = wrappedValue
  }
}
