public protocol ParsedArgumentProtocol: Sendable {}

public protocol ArgumentProtocol: Sendable {
  associatedtype Parsed: ParsedArgumentProtocol

  var fullName: String { get }
  var shortName: String? { get }
  var negatable: Bool { get }
  var help: String? { get }

  static var rangeSize: Int { get }

  //func getRange<C: Collection>(in array: borrowing C) -> Range<C.Index>?
  //where C.Element == String,
  //      C.Index == Int

  func getParsed<C: Collection>(in array: borrowing C, range: Range<Int>) throws -> Self.Parsed
  where C.Element == String,
        C.Index == Int
}

extension ArgumentProtocol {
  public func getRange<C: Collection>(in array: borrowing C) -> Range<C.Index>?
  where C.Element == String,
        C.Index == Int
  {
    let fullName = "--" + self.fullName
    if let index = array.firstIndex(where: { $0 == fullName }) {
      return index..<index.advanced(by: Self.rangeSize)
    }

    if let shortName = self.shortName {
      let shortArg = "-" + shortName
      if let index = array.firstIndex(where: { $0 == shortArg }) {
        return index..<index.advanced(by: Self.rangeSize)
      }
    }

    if negatable {
      let fullName = "--no-" + self.fullName
      if let index = array.firstIndex(where: { $0 == fullName }) {
        return index..<index.advanced(by: Self.rangeSize)
      }
    }

    return nil
  }
}
