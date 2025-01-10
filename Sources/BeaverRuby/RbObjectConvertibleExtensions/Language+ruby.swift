import RubyGateway
import Beaver

extension Language: RbObjectConvertible {
  public init?(_ value: RbObject) {
    switch (value.rubyType) {
      case .T_STRING: fallthrough
      case .T_SYMBOL:
        guard let lang = Language(fromString: value.description) else {
          return nil
        }
        self = lang
      default:
        return nil
    }
  }

  public var rubyObject: RbObject {
    self.description.rubyObject
  }
}
