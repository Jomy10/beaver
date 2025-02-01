@preconcurrency import SQLite

struct TableColumn<ColumnType> {
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
  //var qualified: SQLite.Expression<ColumnType>
  //var unqualified: SQLite.Expression<ColumnType>

  init(_ columnName: String, _ table: Table) {
    self.table = table
    self.expression = SQLite.Expression<ColumnType>(columnName)
    self.columnName = columnName
    //self.unqualified = SQLite.Expression<ColumnType>(columnName)
    //self.qualified = table[self.unqualified]
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
