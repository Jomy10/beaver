public struct ExecutableRunError: TargetError {
  static public let errorTypeName: String = "RunError"

  public let target: TargetRef
  public let targetName: String
  public let reason: ReasonType

  public enum ReasonType: Sendable {
    case noExecutable
  }

  public init(_ target: borrowing any Target, _ reason: ReasonType) {
    self.target = target.ref
    self.targetName = target.name
    self.reason = reason
  }
}
