import SQLite

extension UInt64: SQLite.Value {
  public typealias Datatype = Int64

  public static var declaredDatatype: String {
    "INTEGER"
  }

  public static func fromDatatypeValue(_ datatypeValue: Datatype) throws -> UInt64 {
    UInt64(bitPattern: datatypeValue)
  }

  public var datatypeValue: Int64 {
    Int64(bitPattern: self)
  }
}

extension OptimizationMode: SQLite.Value {
  public typealias Datatype = Int64

  public static var declaredDatatype: String {
    "INT"
  }

  struct InvalidDatatypeValue: Error {
    let value: Int64
  }

  public static func fromDatatypeValue(_ datatypeValue: Datatype) throws -> ValueType {
    switch (datatypeValue) {
      case 0: return .debug
      case 1: return .release
      default:
        throw InvalidDatatypeValue(value: datatypeValue)
    }
  }

  public var datatypeValue: Datatype {
    switch (self) {
      case .debug: 0
      case .release: 1
    }
  }
}

extension CacheVarVal: SQLite.Value {
  public typealias DataType = String

  public static var declaredDatatype: String {
    String.declaredDatatype
  }

  struct InvalidDatatypeValue: Error {
    let value: String
  }

  public static func fromDatatypeValue(_ datatypeValue: DataType) throws -> ValueType {
    let components = datatypeValue.split(separator: ":", maxSplits: 1)
    switch (components[0]) {
      case "string":
        return .string(String(components[1]))
      case "int":
        return .int(Int(components[1])!)
      case "double":
        return .double(Double(components[1])!)
      case "bool":
        return .bool(components[1] == "true")
      case "none":
        return .none
      default:
        throw InvalidDatatypeValue(value: datatypeValue)
    }
  }

  public var datatypeValue: DataType {
    switch (self) {
      case .string(let val): "string:\(val)"
      case .int(let i): "int:\(i)"
      case .double(let d): "double:\(d)"
      case .bool(let b): "bool:\(b)"
      case .none: "none"
    }
  }
}

extension CObjectType: SQLite.Value {
  public typealias DataType = Int64

  public static var declaredDatatype: String {
    Int64.declaredDatatype
  }

  struct InvalidDatatypeValue: Error {
    let value: Int64
  }

  public static func fromDatatypeValue(_ datatypeValue: DataType) throws -> ValueType {
    switch (datatypeValue) {
      case 0: return .static
      case 1: return .dynamic
      default: throw InvalidDatatypeValue(value: datatypeValue)
    }
  }

  public var datatypeValue: DataType {
    switch (self) {
      case .static: return 0
      case .dynamic: return 1
    }
  }
}

extension ArtifactType: SQLite.Value {
  public typealias Datatype = Int64

  public static var declaredDatatype: String {
    "INTEGER"
  }

  struct InvalidDatatypeValue: Error {
    let value: Int64
  }

  public static func fromDatatypeValue(_ datatypeValue: Datatype) throws -> ValueType {
    switch (datatypeValue) {
      case 0..<100:
        guard let val = ExecutableArtifactType(fromSQLValue: datatypeValue) else {
          throw InvalidDatatypeValue(value: datatypeValue)
        }
        return .executable(val)
      case 100..<200:
        guard let val = LibraryArtifactType(fromSQLValue: datatypeValue - 100) else {
          throw InvalidDatatypeValue(value: datatypeValue)
        }
        return .library(val)
      default:
        throw InvalidDatatypeValue(value: datatypeValue)
    }
  }

  public var datatypeValue: Datatype {
    switch (self) {
      case .executable(let artifact): artifact.sqlValue
      case .library(let artifact): 100 + artifact.sqlValue
    }
  }
}

fileprivate extension ExecutableArtifactType {
  var sqlValue: Int64 {
    switch (self) {
      case .executable: return 0
      case .app: return 1
    }
  }

  init?(fromSQLValue val: Int64) {
    switch (val) {
      case 0: self = .executable
      case 1: self = .app
      default: return nil
    }
  }
}

fileprivate extension LibraryArtifactType {
  var sqlValue: Int64 {
    switch (self) {
      case .staticlib: return 0
      case .dynlib: return 1
      case .pkgconfig: return 2
      case .framework: return 3
      case .xcframework: return 4
    }
  }

  init?(fromSQLValue val: Int64) {
    switch (val) {
      case 0: self = .staticlib
      case 1: self = .dynlib
      case 2: self = .pkgconfig
      case 3: self = .framework
      case 4: self = .xcframework
      default: return nil // TODO
    }
  }
}

extension DependencyType: SQLite.Value {
  public typealias Datatype = Int

  public static var declaredDatatype: String {
    "INTEGER"
  }

  struct InvalidDatatypeValue: Error {
    let value: Int
  }

  public static func fromDatatypeValue(_ datatypeValue: Datatype) throws -> ValueType {
    guard let t = DependencyType(rawValue: datatypeValue) else {
      throw InvalidDatatypeValue(value: datatypeValue)
    }
    return t
  }

  public var datatypeValue: Datatype {
    self.rawValue
  }
}

extension TargetType: SQLite.Value {
  public typealias Datatype = Int

  public static var declaredDatatype: String {
    "INTEGER"
  }

  struct InvalidDatatypeValue: Error {
    let value: Int
  }

  public static func fromDatatypeValue(_ datatypeValue: Datatype) throws -> ValueType {
    guard let t = TargetType(rawValue: Int8(datatypeValue)) else {
      throw InvalidDatatypeValue(value: datatypeValue)
    }
    return t
  }

  public var datatypeValue: Datatype {
    Int(self.rawValue)
  }
}

extension Dependency {
  var stringValue: String? {
    switch (self) {
      case .pkgconfig(let pkgConfig):
        pkgConfig.name + "|preferStatic:\(pkgConfig.preferStatic)"
      case .system(let name):
        name
      case .customFlags(cflags: let cflags, linkerFlags: let linkerFlags):
        "cflags:\(cflags),linkerflags:\(linkerFlags)"
      case .library(_):
        nil
      case .cmakeId(let cmakeId):
        "cmakeId:\(cmakeId)"
    }
  }
}
