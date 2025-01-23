import Foundation
@preconcurrency import SQLite

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

  let tableName: String

  init() {
    self.tableName = "File"
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

  let tableName: String

  init() {
    self.tableName = "CSourceFile"
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

  let tableName: String

  init() {
    self.tableName = "Configuration"
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

  let tableName: String

  init() {
    self.tableName = "Target"
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

struct GlobalConfigurationTable: SQLTable {
  let table: Table
  /// The build id of the current Beaver build. This is reset every time that Beaver is rebuilt
  let buildId: TableColumn<Int>
  /// An md5 hash computed from the environment variables
  let environment: TableColumn<Data>

  let tableName: String

  init() {
    self.tableName = "GlobalConfiguration"
    self.table = Table(self.tableName)
    self.buildId = TableColumn("buildId", self.table)
    self.environment = TableColumn("env", self.table)
  }

  func createIfNotExists(_ db: Connection) throws {
    try db.run(self.table.create(ifNotExists: true) { t in
      t.column(self.buildId.unqualified)
      t.column(self.environment.unqualified)
    })
  }
}

struct DependencyFileTable: SQLTable {
  let table: Table
  // A file (artifact) the config, target and artifact combination depend on
  let fileId: TableColumn<Int64>
  // A target with a given config for building a specific artifact
  let configId: TableColumn<Int64>
  let targetId: TableColumn<Int64>
  let artifactType: TableColumn<ArtifactType>

  let tableName: String

  init() {
    self.tableName = "DependencyFile"
    self.table = Table(self.tableName)
    self.fileId = TableColumn("fileID", self.table)
    self.configId = TableColumn("configID", self.table)
    self.targetId = TableColumn("targetID", self.table)
    self.artifactType = TableColumn("artifactType", self.table)
  }

  func createIfNotExists(_ db: Connection) throws {
    try db.run(self.table.create(ifNotExists: true) { t in
      t.column(self.fileId.unqualified)
      t.column(self.configId.unqualified)
      t.column(self.targetId.unqualified)
      t.column(self.artifactType.unqualified)

      t.primaryKey(
        self.fileId.unqualified,
        self.configId.unqualified,
        self.targetId.unqualified,
        self.artifactType.unqualified
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

struct CustomFileTable: SQLTable {
  let table: Table
  let fileId: TableColumn<Int64>
  let context: TableColumn<String>

  let tableName: String

  init() {
    self.tableName = "CustomFile"
    self.table = Table(self.tableName)
    self.fileId = TableColumn("fileID", self.table)
    self.context = TableColumn("context", self.table)
  }

  func createIfNotExists(_ db: Connection) throws {
    try db.run(self.table.create(ifNotExists: true) { t in
      t.column(self.fileId.unqualified)
      t.column(self.context.unqualified)

      t.primaryKey(self.fileId.unqualified, self.context.unqualified)

      t.foreignKey(
        self.fileId.unqualified,
        references: Table("File"), SQLite.Expression<Int64>("id"))
    })
  }
}

struct TempInputFileTable: SQLTempTable {
  let table: Table
  let filename: TableColumn<String>

  let tableName: String

  init() {
    self.tableName = "InputFile_\(UUID())"
    self.table = Table(self.tableName)
    self.filename = TableColumn("filename", self.table)
  }

  func create(_ db: Connection) throws {
    try db.run(self.table.create(temporary: true) { t in
      t.column(self.filename.unqualified, primaryKey: true)
    })
  }

  func insert(_ inputFiles: [URL], _ db: Connection) throws {
    try db.run(self.table.insertMany(inputFiles.map { [self.filename.unqualified <- $0.absoluteURL.path] }))
  }
}
