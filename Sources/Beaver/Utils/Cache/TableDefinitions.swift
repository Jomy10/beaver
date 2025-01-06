import Foundation
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

struct FileTable: SQLTable {
  let table: Table
  let id: TableColumn<Int64>
  let filename: TableColumn<String>
  let mtime: TableColumn<Int64>
  let size: TableColumn<Int64>
  let inodeNumber: TableColumn<UInt64>
  let fileMode: TableColumn<UInt64>
  let ownerUid: TableColumn<UInt64>
  let ownerGid: TableColumn<UInt64>

  init() {
    self.table = Table("File")
    self.id = TableColumn("id", self.table)
    self.filename = TableColumn("filename", self.table)
    self.mtime = TableColumn("mtime", self.table)
    self.size = TableColumn("size", self.table)
    self.inodeNumber = TableColumn("ino", self.table)
    self.fileMode = TableColumn("mode", self.table)
    self.ownerUid = TableColumn("uid", self.table)
    self.ownerGid = TableColumn("gid", self.table)
  }

  func createIfNotExists(_ db: Connection) throws {
    try db.run(self.table.create(ifNotExists: true) { t in
      t.column(self.id.unqualified, primaryKey: .autoincrement)
      t.column(self.filename.unqualified)
      t.column(self.mtime.unqualified)
      t.column(self.size.unqualified)
      t.column(self.inodeNumber.unqualified)
      t.column(self.fileMode.unqualified)
      t.column(self.ownerUid.unqualified)
      t.column(self.ownerGid.unqualified)
    })
    try db.run(self.table.createIndex(self.filename.unqualified, ifNotExists: true))
  }
}

/// Points to a source file, a given configuration and target and the type of object that
/// has to be compiled (dynamic or static)
struct CSourceFileTable: SQLTable {
  let table: Table
  let fileId: TableColumn<Int64>
  let configId: TableColumn<Int64>
  let targetId: TableColumn<Int64>
  let objectType: TableColumn<CObjectType>

  init() {
    self.table = Table("CSourceFile")
    self.fileId = TableColumn("fileID", self.table)
    self.configId = TableColumn("configID", self.table)
    self.targetId = TableColumn("targetID", self.table)
    self.objectType = TableColumn("objectType", self.table)
  }

  func createIfNotExists(_ db: Connection) throws {
    try db.run(self.table.create(ifNotExists: true) { t in
      t.column(self.fileId.unqualified)
      t.column(self.configId.unqualified)
      t.column(self.targetId.unqualified)
      t.column(self.objectType.unqualified)

      t.primaryKey(
        self.fileId.unqualified,
        self.configId.unqualified,
        self.targetId.unqualified,
        self.objectType.unqualified
      )

      t.foreignKey(
        self.fileId.unqualified,
        references: Table("File"), SQLite.Expression<Int64>("id"))
      t.foreignKey(
        self.configId.unqualified,
        references: Table("Configuration"), SQLite.Expression<Int64>("id"))
      t.foreignKey(
        self.targetId.unqualified,
        references: Table("Target"), SQLite.Expression<Int64>("id"))
    })
  }
}

struct ConfigurationTable: SQLTable {
  let table: Table
  let id: TableColumn<Int64>
  let mode: TableColumn<OptimizationMode>

  init() {
    self.table = Table("Configuration")
    self.id = TableColumn("id", self.table)
    self.mode = TableColumn("mode", self.table)
  }

  func createIfNotExists(_ db: Connection) throws {
    try db.run(self.table.create(ifNotExists: true) { t in
      t.column(self.id.unqualified, primaryKey: .autoincrement)
      t.column(self.mode.unqualified)
    })
  }
}

struct TargetTable: SQLTable {
  let table: Table
  let id: TableColumn<Int64>
  let project: TableColumn<Int>
  let target: TableColumn<Int>

  init() {
    self.table = Table("Target")
    self.id = TableColumn("id", self.table)
    self.project = TableColumn("project", self.table)
    self.target = TableColumn("target", self.table)
  }

  func createIfNotExists(_ db: Connection) throws {
    try db.run(self.table.create(ifNotExists: true) { t in
      t.column(self.id.unqualified, primaryKey: .autoincrement)
      t.column(self.target.unqualified)
      t.column(self.project.unqualified)
    })
  }
}

struct TempInputFileTable: SQLTempTable {
  let table: Table
  let filename: TableColumn<String>

  init() {
    self.table = Table("InputFile_\(UUID())")
    self.filename = TableColumn("filename", self.table)
  }

  func create(_ db: Connection) throws {
    try db.run(self.table.create(temporary: true) { t in
      t.column(self.filename.unqualified, primaryKey: true)
    })
  }
}
