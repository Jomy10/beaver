@preconcurrency import SQLite

public struct TableColumn<ColumnType>: Sendable {
  let table: Table
  let expression: SQLite.Expression<ColumnType>
  let columnName: String

  var qualified: SQLite.Expression<ColumnType> {
    self.table[self.expression]
  }
  var unqualified: SQLite.Expression<ColumnType> {
    self.expression
  }
  var qualifiedOptional: SQLite.Expression<ColumnType?> {
    self.table[SQLite.Expression<ColumnType?>(self.columnName)]
  }
  var unqualifiedOptional: SQLite.Expression<ColumnType?> {
    self.table[SQLite.Expression<ColumnType?>(self.columnName)]
  }

  init(_ columnName: String, _ table: Table) {
    self.table = table
    self.expression = SQLite.Expression<ColumnType>(columnName)
    self.columnName = columnName
  }
}

public protocol CacheEntry {
  associatedtype Columns

  init(_ row: Row)

  static var table: Table { get }
  static var tableName: String { get }
  static func createIfNotExists(_ db: Connection) throws
  static func createTemporary(_ db: Connection) throws -> Table
  static func getOne(_ db: Connection) throws -> Row?

  var setter: [SQLite.Setter] { get }
  /// returns the last id inserted
  @discardableResult
  static func insertMany(_ entries: [Self], _ db: Connection) throws -> Int64
  /// Returns the row id of the inserted entry
  @discardableResult
  func insert(_ db: Connection) throws -> Int64
}

extension CacheEntry {
  public static var table: Table {
    Table(Self.tableName)
  }
}
