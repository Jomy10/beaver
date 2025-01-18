import RubyGateway
import Beaver

extension Headers: FailableRbObjectConvertible {
  public init(_ value: RbObject) throws {
    switch (value.rubyType) {
      case .T_NIL:
        self.init()
      case .T_ARRAY:
        self.init(public: try value.convert())
      case .T_STRING:
        self.init(public: [try value.convert(to: String.self)])
        //let files = try Files(value)
        //self.init(public: files)
      case .T_HASH:
        let hash = try value.convert(to: Dictionary<String, [String]>.self)
        self.init(
          public: hash["public"] ?? [String](),
          private: hash["private"] ?? [String]()
        )
      default:
        throw RbConversionError.incompatible(from: value.rubyType, to: Self.self)
    }
  }

  public var rubyObject: RbObject {
    fatalError("unimplemented")
  }
}
