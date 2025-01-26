public struct TargetBuildError: TargetError {
  static public let errorTypeName: String = "BuildError"

  public let target: TargetRef
  public let targetName: String
  public let reason: ReasonType

  public enum ReasonType: Sendable {
  }

  public init<T: Target & ~Copyable>(_ target: borrowing T, _ reason: ReasonType) {
    self.target = target.ref
    self.targetName = target.name
    self.reason = reason
  }
}
