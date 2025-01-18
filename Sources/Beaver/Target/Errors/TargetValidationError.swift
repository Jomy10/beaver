public struct TargetValidationError: TargetError {
  public static let errorTypeName: String = "ValidationError"

  public let target: TargetRef
  public let targetName: String
  public let reason: ReasonType

  public enum ReasonType: Sendable {
    case invalidLanguage(Language)
    case noSources
    case unsupportedArtifact(ArtifactType)
  }

  public init(_ target: borrowing any Target, _ reason: ReasonType) {
    self.target = target.ref
    self.targetName = target.name
    self.reason = reason
  }
}
