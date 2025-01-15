public protocol Cli {
  static var _arguments: [any ArgumentProtocol] { get }

  init(arguments: borrowing [String].SubSequence) throws

  func validate() throws(ValidationError)
  mutating func takeArgument() -> String?

  var leftoverArguments: DiscontiguousSlice<Array<String>.SubSequence> { get set }

  static func parseArguments<C: Collection>(_ arguments: borrowing C) throws -> (DiscontiguousSlice<C>, [String:any ParsedArgumentProtocol])
  where C.Element == String,
        C.Index == Int
}

extension Cli {
  public static func parseArguments<C: Collection>(_ arguments: borrowing C) throws -> (DiscontiguousSlice<C>, [String:any ParsedArgumentProtocol])
  where C.Element == String,
        C.Index == Int
  {
    var ranges: [(any ArgumentProtocol, Range<Int>)] = []
    for arg in self._arguments {
      if let range = arg.getRange(in: arguments) {
        ranges.append((arg, range))
      }
    }

    for (i, (arg, range)) in ranges.enumerated() {
      for (j, (arg2, range2)) in ranges.enumerated() {
        if i == j { continue }
        if range2.overlaps(range) {
          throw ValidationError("Argument '\(arg2.fullName)' overlaps with value of argument '\(arg.fullName)'. If this is intentional, escape the leading dash with a '\\'. e.g. --\(arg.fullName) \\--\(arg2.fullName)")
        }
      }
    }

    let rangeSet = RangeSet(ranges.map { $0.1 })
    var parsedArgs = [String:any ParsedArgumentProtocol]()
    parsedArgs.reserveCapacity(ranges.count)
    for (arg, range) in ranges {
      parsedArgs[arg.fullName] = try arg.getParsed(in: arguments, range: range)
    }
    let array = arguments.removingSubranges(rangeSet)
    return (array, parsedArgs)
  }

  public func validate() throws(ValidationError) {}

  public mutating func takeArgument() -> String? {
    if let arg = self.leftoverArguments.first {
      if arg.starts(with: "-") {
        return nil
      } else {
        self.leftoverArguments.removeFirst()
        return arg
      }
    } else {
      return nil
    }
  }
}
