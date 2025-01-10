import RubyGateway
import Beaver

extension ArtifactTypeProtocol {
  public init?(_ value: RbObject) {
    if value.rubyType == .T_STRING || value.rubyType == .T_SYMBOL {
      guard let val = Self(value.description) else {
        return nil
      }
      self = val
    } else {
      return nil
    }
  }

  public var rubyObject: RbObject {
    fatalError("unimplemented")
  }
}

extension LibraryArtifactType: RbObjectConvertible {}
extension ExecutableArtifactType: RbObjectConvertible {}
