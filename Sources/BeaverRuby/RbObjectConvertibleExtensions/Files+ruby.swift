import RubyGateway
import Beaver

extension Files: FailableRbObjectConvertible {
  public init(_ value: RbObject) throws {
    switch (value.rubyType) {
      case .T_HASH:
        //let hash: [RbObject:RbObject] = try value.convert()
        var include: Files.Storage? = nil
        var exclude: Files.Storage? = nil
        var includeHiddenFiles: Bool = false
        try value.call("each") { args in
          let kvArrayObj = args[0]
          let key = kvArrayObj[0].description
          let val = kvArrayObj[1]
          //let key = k.description

          switch (key) {
            case "include":
              include = try Files.Storage(val)
            case "exclude":
              exclude = val.isNil ? nil : try Files.Storage(val)
            case "includeHiddenFiles":
              includeHiddenFiles = try val.convert()
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
          exclude: exclude,
          includeHiddenFiles: includeHiddenFiles
        )
      case .T_STRING: fallthrough
      case .T_ARRAY:
        self = Files(include: try Files.Storage(value))
      default:
        throw RbConversionError.incompatible(from: value.rubyType, to: Self.self)
    }
  }
}

extension Files.Storage: FailableRbObjectConvertible {
  public init(_ value: RbObject) throws {
    switch (value.rubyType) {
      case .T_STRING:
        let globPat: String = try value.convert()
        self = .glob(globPat)
      case .T_ARRAY:
        let globArray: Array<String> = try value.convert()
        self = .globArray(globArray)
      default:
        throw RbConversionError.incompatible(from: value.rubyType, to: Self.self)
    }
  }
}
