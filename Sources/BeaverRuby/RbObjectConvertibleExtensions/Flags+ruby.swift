import RubyGateway
import Beaver

extension Flags: RbObjectConvertible {
  public init?(_ value: RbObject) {
    switch (value.rubyType) {
      case .T_ARRAY:
        guard let arr = Array<String>(value) else { return nil }
        self.init(public: arr)
      case .T_NIL:
        self.init()
      case .T_STRING:
        guard let str = String(value) else { return nil }
        self.init(public: [str])
      case .T_HASH:
        guard let hash = Dictionary<String, [String]>(value) else { return nil }
        self.init(
          public: hash["public"] ?? [],
          private: hash["private"] ?? []
        )
      default:
        return nil
    }
  }

  public var rubyObject: RbObject {
    fatalError("unimplemented")
  }
}
