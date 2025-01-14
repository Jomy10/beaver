public struct ArgumentDecl: Sendable, ArgumentProtocol {
  public var fullName: String
  public var shortName: String?
  public var help: String?

  public var negatable: Bool { false }

  public static let rangeSize: Int = 2

  public init(fullName: String, shortName: String?, help: String?) {
    self.fullName = fullName
    self.shortName = shortName
    self.help = help
  }

  public struct Parsed: Sendable, ParsedArgumentProtocol {
    public let name: String
    public let value: String
  }

  public func getParsed<C: Collection>(in array: borrowing C, range: Range<Int>) throws -> ArgumentDecl.Parsed
  where C.Element == String,
        C.Index == Int
  {
    if range.endIndex - 1 == array.endIndex {
      throw ValidationError("no value provided for --\(self.fullName)")
    }
    let value: String = array[range.endIndex - 1]
    return Self.Parsed(name: self.fullName, value: value)
  }
}

@propertyWrapper
public struct Argument<T: Sendable>: Sendable {
  public var wrappedValue: T

  public init(
    wrappedValue: T,
    name: String,
    shortName: String? = nil,
    help: String? = nil,
    default: (() -> T)? = nil
  ) {
    self.wrappedValue = wrappedValue
  }
}
