import RubyGateway
import Beaver

extension Version: RbObjectConvertible {
  public init?(_ value: RbObject) {
    if value.rubyType == .T_STRING {
      self = Version(value.description)
    } else {
      return nil
    }
  }

  public var rubyObject: RbObject {
    fatalError("unimplemented")
  }
}
