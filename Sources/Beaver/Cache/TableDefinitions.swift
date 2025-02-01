import Foundation
@preconcurrency import SQLite
import timespec

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

  func update(id: Int64, _ attrs: stat, _ db: Connection) throws {
    try db.run(self.table
      .where(self.id.qualified == id)
      .update([
        self.mtime.unqualified <- Int64(timespec_to_ms(attrs.st_mtimespec)),
        self.size.unqualified <- Int64(attrs.st_size),
        self.inodeNumber.unqualified <- UInt64(attrs.st_ino),
        self.fileMode.unqualified <- UInt64(attrs.st_mode),
        self.ownerUid.unqualified <- UInt64(attrs.st_uid),
        self.ownerGid.unqualified <- UInt64(attrs.st_gid),
      ])
    )
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

struct TargetCacheTable: SQLTable {
  let table: Table
  let targetId: TableColumn<Int64>
  let project: TableColumn<String>
  let target: TableColumn<String>
  let targetType: TableColumn<TargetType>

  let tableName: String

  init() {
    self.tableName = "TargetCache"
    self.table = Table(self.tableName)
    self.targetId = TableColumn("targetID", self.table)
    self.project = TableColumn("project", self.table)
    self.target = TableColumn("target", self.table)
    self.targetType = TableColumn("targetType", self.table)
  }

  func createIfNotExists(_ db: Connection) throws {
    try db.run(self.table.create(ifNotExists: true) { t in
      t.column(self.targetId.unqualified, primaryKey: true)
      t.column(self.project.unqualified)
      t.column(self.target.unqualified)
      t.column(self.targetType.unqualified)

      t.foreignKey(
        self.targetId.unqualified,
        references: Table("Target"), SQLite.Expression<Int64>("id"))
    })
  }
}

struct TargetDependencyCacheTable: SQLTable {
  let table: Table
  let targetId: TableColumn<Int64>
  let dependencyType: TableColumn<DependencyType>
  let artifactType: TableColumn<ArtifactType?>
  let dependencyTargetId: TableColumn<Int64?>
  let stringData: TableColumn<String?>

  let tableName: String

  init() {
    self.tableName = "TargetDependencyCache"
    self.table = Table(self.tableName)
    self.targetId = TableColumn("targetID", self.table)
    self.dependencyType = TableColumn("dependencyType", self.table)
    self.artifactType = TableColumn("artifactType", self.table)
    self.dependencyTargetId = TableColumn("dependencyTargetID", self.table)
    self.stringData = TableColumn("stringData", self.table)
  }

  func createIfNotExists(_ db: Connection) throws {
    try db.run(self.table.create(ifNotExists: true) { t in
      t.column(self.targetId.unqualified)
      t.column(self.dependencyType.unqualified)
      t.column(self.artifactType.unqualified)
      t.column(self.dependencyTargetId.unqualified)
      t.column(self.stringData.unqualified)

      t.foreignKey(
        self.targetId.unqualified,
        references: Table("Target"), SQLite.Expression<Int64>("id"))
      t.foreignKey(
        self.dependencyTargetId.unqualified,
        references: Table("Target"), SQLite.Expression<Int64>("id"))
    })
  }
}

struct OutputFileTable: SQLTable {
  let table: Table
  //let fileId: TableColumn<Int64>
  let filename: TableColumn<String>
  let configId: TableColumn<Int64>
  let targetId: TableColumn<Int64>
  let artifactType: TableColumn<ArtifactType>
  let relink: TableColumn<Bool>

  let tableName: String

  init() {
    self.tableName = "OutputFile"
    self.table = Table(self.tableName)
    self.filename = TableColumn("filename", self.table)
    self.configId = TableColumn("configID", self.table)
    self.targetId = TableColumn("targetID", self.table)
    self.artifactType = TableColumn("artifactType", self.table)
    self.relink = TableColumn("relink", self.table)
  }

  func createIfNotExists(_ db: Connection) throws {
    try db.run(self.table.create(ifNotExists: true) { t in
      t.column(self.filename.unqualified)
      t.column(self.configId.unqualified)
      t.column(self.targetId.unqualified)
      t.column(self.artifactType.unqualified)
      t.column(self.relink.unqualified)

      t.foreignKey(
        self.targetId.unqualified,
        references: Table("Target"), SQLite.Expression<Int64>("id"))
      t.foreignKey(
        self.configId.unqualified,
        references: Table("Configuration"), SQLite.Expression<Int64>("id"))
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
    self.buildId = TableColumn("buildID", self.table)
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
  let configId: TableColumn<Int64>
  let context: TableColumn<String>

  let tableName: String

  init() {
    self.tableName = "CustomFile"
    self.table = Table(self.tableName)
    self.fileId = TableColumn("fileID", self.table)
    self.configId = TableColumn("configID", self.table)
    self.context = TableColumn("context", self.table)
  }

  func createIfNotExists(_ db: Connection) throws {
    try db.run(self.table.create(ifNotExists: true) { t in
      t.column(self.fileId.unqualified)
      t.column(self.configId.unqualified)
      t.column(self.context.unqualified)

      t.primaryKey(self.fileId.unqualified, self.context.unqualified, self.configId.unqualified)

      t.foreignKey(
        self.fileId.unqualified,
        references: Table("File"), SQLite.Expression<Int64>("id"))
      t.foreignKey(
        self.configId.unqualified,
        references: Table("Configuration"), SQLite.Expression<Int64>("id"))
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

struct TempTargetTable: SQLTempTable {
  let table: Table
  let target: TableColumn<Int>
  let targetName: TableColumn<String>
  let project: TableColumn<Int>
  let projectName: TableColumn<String>

  let tableName: String

  init() {
    self.tableName = "Target_\(UUID())"
    self.table = Table(self.tableName)
    self.target = TableColumn("target", self.table)
    self.targetName = TableColumn("targetName", self.table)
    self.project = TableColumn("project", self.table)
    self.projectName = TableColumn("projectName", self.table)
  }

  func create(_ db: Connection) throws {
    try db.run(self.table.create(temporary: true) { t in
      t.column(self.target.unqualified)
      t.column(self.targetName.unqualified)
      t.column(self.project.unqualified)
      t.column(self.projectName.unqualified)
    })
  }

  func insert(
    _ targets: [(projectId: Int, projectName: String, targetId: Int, targetName: String)],
    _ db: Connection
  ) throws {
    try db.run(self.table.insertMany(targets.map { target in
      [
        self.target.unqualified <- target.targetId,
        self.targetName.unqualified <- target.targetName,
        self.project.unqualified <- target.projectId,
        self.projectName.unqualified <- target.projectName
      ]
    }))
  }
}

struct TempTargetDependencyTable: SQLTempTable {
  let table: Table
  let dependencyType: TableColumn<DependencyType>
  let artifactType: TableColumn<ArtifactType?>
  let dependencyTarget: TableColumn<Int?>
  let dependencyProject: TableColumn<Int?>
  let stringData: TableColumn<String?>

  let tableName: String

  init() {
    self.tableName = "TargetDependency_\(UUID())"
    self.table = Table(self.tableName)
    self.dependencyType = TableColumn("dependencyType", self.table)
    self.artifactType = TableColumn("artifactType", self.table)
    self.dependencyTarget = TableColumn("depTarget", self.table)
    self.dependencyProject = TableColumn("depProject", self.table)
    self.stringData = TableColumn("stringData", self.table)
  }

  func create(_ db: Connection) throws {
    try db.run(self.table.create(temporary: true) { t in
      t.column(self.dependencyType.unqualified)
      t.column(self.artifactType.unqualified)
      t.column(self.dependencyTarget.unqualified)
      t.column(self.dependencyProject.unqualified)
      t.column(self.stringData.unqualified)
    })
  }

  func insert(_ dependencies: [Dependency], _ db: Connection) throws {
    print("inserting: \(dependencies)")
    try db.run(self.table.insertMany(dependencies.map { dependency in
      var inserts: [Setter] = Array()
      inserts.reserveCapacity(5)
      inserts.append(self.dependencyType.unqualified <- dependency.type)
      switch (dependency) {
        case .library(let lib):
          inserts.append(contentsOf: [
            self.artifactType.unqualified <- lib.artifact.asArtifactType(),
            self.dependencyTarget.unqualified <- lib.target.target,
            self.dependencyProject.unqualified <- lib.target.project,
            self.stringData.unqualified <- nil,
          ])
        default:
          inserts.append(contentsOf: [
            self.artifactType.unqualified <- nil,
            self.dependencyTarget.unqualified <- nil,
            self.dependencyProject.unqualified <- nil,
            self.stringData.unqualified <- dependency.stringValue!
          ])
      }
      print("inserts: \(inserts)")
      return inserts
    }))
  }
}
