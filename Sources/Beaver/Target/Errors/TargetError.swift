public protocol TargetError: Error, CustomStringConvertible {
  associatedtype ReasonType: Sendable

  var target: TargetRef { get }
  var targetName: String { get }
  var reason: ReasonType { get }
  static var errorTypeName: String { get }

  //init(_ target: borrowing any Target & ~Copyable, _ reason: ReasonType)
  init<T: Target & ~Copyable>(_ target: borrowing T, _ reason: ReasonType)
}

extension TargetError {
  public var description: String {
    "\(Self.errorTypeName): \(self.reason) @ \(self.targetName)"
  }
}
