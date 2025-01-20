@preconcurrency import SQLite

struct TableColumn<ColumnType: SQLite.Value> {
  var qualified: SQLite.Expression<ColumnType>
  var unqualified: SQLite.Expression<ColumnType>

  init(_ columnName: String, _ table: borrowing Table) {
    self.unqualified = SQLite.Expression<ColumnType>(columnName)
    self.qualified = table[self.unqualified]
  }
}

protocol SQLTableProtocol: Sendable {
  var table: Table { get }
  var tableName: String { get }
  func truncate(_ db: Connection) throws
}

extension SQLTableProtocol {
  func truncate(_ db: Connection) throws {
    try db.run(self.table.delete())
  }
}

protocol SQLTable: SQLTableProtocol {
  func createIfNotExists(_ db: Connection) throws
}

protocol SQLTempTable: SQLTableProtocol {
  func create(_ db: Connection) throws
}
