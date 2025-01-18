import RubyGateway
import Beaver

extension Files: FailableRbObjectConvertible {
  static func convertInner(_ val: RbObject) throws -> [String] {
    switch (val.rubyType) {
      case .T_ARRAY:
        return try val.convert()
      case .T_STRING:
        return [try val.convert(to: String.self)]
      default:
        throw RbConversionError.unexpectedType(got: val.rubyType, expected: [.T_ARRAY, .T_STRING])
    }
  }

  public init(_ value: RbObject) throws {
    switch (value.rubyType) {
      case .T_HASH:
        //let hash: [RbObject:RbObject] = try value.convert()
        var include: Files.Storage? = nil
        var exclude: Files.Storage? = nil
        var skipHiddenFiles: Bool = true
        try value.call("each") { args in
          let kvArrayObj = args[0]
          let key = kvArrayObj[0].description
          let val = kvArrayObj[1]
          //let key = k.description

          switch (key) {
            case "include":
              include = try Self.convertInner(val)
            case "exclude":
              exclude = val.isNil ? nil : try Self.convertInner(val)
            case "skipHiddenFiles":
              skipHiddenFiles = try val.convert()
            default:
              throw RbConversionError.unexpectedKey(key: key, type: Self.self)
          }

          return RbObject.nilObject
        }
        guard let include = include else {
          throw RbConversionError.keyNotFound(key: "include", type: Self.self)
        }
        self = Files(
          include: include,
          exclude: exclude ?? [],
          skipHiddenFiles: skipHiddenFiles
        )
      case .T_STRING:
        self = Files(include: [try value.convert(to: String.self)])
      case .T_ARRAY:
        self = Files(include: try value.convert())
      default:
        throw RbConversionError.incompatible(from: value.rubyType, to: Self.self)
    }
  }
}

//extension Files.Storage: FailableRbObjectConvertible {
//  public init(_ value: RbObject) throws {
//    switch (value.rubyType) {
//      case .T_STRING:
//        let globPat: String = try value.convert()
//        self = .globPat)
//      case .T_ARRAY:
//        let globArray: Array<String> = try value.convert()
//        self = globArray
//      default:
//        throw RbConversionError.incompatible(from: value.rubyType, to: Self.self)
//    }
//  }
//}
