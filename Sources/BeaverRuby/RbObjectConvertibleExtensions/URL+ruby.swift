import RubyGateway
import Foundation

extension URL: @retroactive RbObjectConvertible {
  public init?(_ value: RbObject) {
    if value.rubyType == .T_STRING {
      guard let url = URL(string: String(value)!) else {
        return nil
      }
      self = url
    } else {
      return nil
    }
  }

  public var rubyObject: RbObject {
    self.path.rubyObject
  }
}
