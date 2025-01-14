import RubyGateway
import Beaver

extension Headers: FailableRbObjectConvertible {
  public init(_ value: RbObject) throws {
    switch (value.rubyType) {
      case .T_NIL:
        self.init()
      case .T_ARRAY: fallthrough
      case .T_STRING:
        let files = try Files(value)
        self.init(public: files)
      case .T_HASH:
        print("headers")
        guard let hash = Dictionary<String, Result<Files, any Error>>(value) else {
          throw RbConversionError.unknownError
        }
        self.init(
          public: (try hash["public"]?.get()) ?? [],
          private: (try hash["private"]?.get()) ?? []
        )
      default:
        throw RbConversionError.incompatible(from: value.rubyType, to: Self.self)
    }
  }

  public var rubyObject: RbObject {
    fatalError("unimplemented")
  }
}
