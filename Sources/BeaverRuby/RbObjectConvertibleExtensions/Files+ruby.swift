import RubyGateway
import Beaver

extension Files: FailableRbObjectConvertible {
  public init(_ value: RbObject) throws {
    switch (value.rubyType) {
      case .T_HASH:
        let hash: [RbObject:RbObject] = try value.convert()
        var include: Files.Storage? = nil
        var exclude: Files.Storage? = nil
        var includeHiddenFiles: Bool = false
        for (k, v) in hash {
          let key = k.description
          switch (key) {
            case "include":
              include = try Files.Storage(v)
            case "exclude":
              exclude = v.isNil ? nil : try Files.Storage(v)
            case "includeHiddenFiles":
              includeHiddenFiles = try v.convert()
            default:
              throw RbConversionError.unexpectedKey(key: key, type: Self.self)
          }
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
