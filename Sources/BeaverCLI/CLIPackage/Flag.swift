public struct FlagDecl: Sendable, ArgumentProtocol {
  public var fullName: String
  public var shortName: String?
  public var help: String?

  public var negatable: Bool = true

  public static let rangeSize: Int = 1

  public init(fullName: String, shortName: String?, negatable: Bool = true, help: String?) {
    self.fullName = fullName
    self.shortName = shortName
    self.help = help
    self.negatable = negatable
  }

  public struct Parsed: Sendable, ParsedArgumentProtocol {
    public let value: Bool
  }

  public func getParsed<C: Collection>(in array: borrowing C, range: Range<Int>) throws -> Self.Parsed
  where C.Element == String,
        C.Index == Int
  {
    return Self.Parsed(value: array[range].first! != ("--no-" + self.fullName))
  }
}

@propertyWrapper
public struct Flag<T: Sendable>: Sendable {
  public var wrappedValue: T

  public init(
    wrappedValue: Bool,
    name: String,
    shortName: String? = nil,
    negatable: Bool = true,
    help: String? = nil,
    default: (() -> Bool)? = nil
  ) where T == Bool {
    self.wrappedValue = wrappedValue
  }

  public init(
    wrappedValue: Bool?,
    name: String,
    shortName: String? = nil,
    negatable: Bool = true,
    help: String? = nil,
    default: (() -> Bool)? = nil
  ) where T == Bool? {
    self.wrappedValue = wrappedValue
  }
}
