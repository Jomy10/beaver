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
      case .dynamiclanglib(_): return 5
      case .staticlanglib(_): return 6
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
