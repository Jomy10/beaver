import Foundation
// SQLite does have its own thread-safe implementation
@preconcurrency import SQLite

/// ```mermaid
/// erDiagram
///
/// SourceFile {
/// 	string filename
/// 	data hash
/// 	int configID
/// 	int targetID
/// 	int artifactType
/// }
///
/// Configuration {
///  int id
/// 	string mode
/// }
///
/// Target {
/// 	int id
/// 	int project
/// 	int target
/// }
///
/// SourceFile }o--|| Configuration: configID
/// SourceFile }o--|| Target: targetID
/// ```
struct FileCache: Sendable {
  let db: Connection
  let sourceFiles: Table
  let sourceFileColumns: (filename: SQLite.Expression<String>, hash: SQLite.Expression<Data>, configID: SQLite.Expression<Int64>, targetID: SQLite.Expression<Int64>, artifactType: SQLite.Expression<ArtifactType>)
  let configurations: Table
  let configurationColumns: (id: SQLite.Expression<Int64>, mode: SQLite.Expression<OptimizationMode>)
  let targets: Table
  let targetColumns: (id: SQLite.Expression<Int64>, project: SQLite.Expression<Int>, target: SQLite.Expression<Int>)

  var configurationId: Int64? = nil

  init(cacheFile: URL) throws {
    self.db = try Connection(cacheFile.path)

    self.sourceFiles = Table("SourceFile")
    self.sourceFileColumns = (
      filename: SQLite.Expression<String>("filename"),
      hash: SQLite.Expression<Data>("hash"),
      configID: SQLite.Expression<Int64>("configID"),
      targetID: SQLite.Expression<Int64>("targetID"),
      artifactType: SQLite.Expression<ArtifactType>("artifactType")
    )
    self.configurations = Table("Configuration")
    self.configurationColumns = (
      id: SQLite.Expression<Int64>("id"),
      mode: SQLite.Expression<OptimizationMode>("mode")
    )
    self.targets = Table("Target")
    self.targetColumns = (
      id: SQLite.Expression<Int64>("id"),
      project: SQLite.Expression<Int>("project"),
      target: SQLite.Expression<Int>("target")
    )

    try db.run(configurations.create(ifNotExists: true) { t in
      t.column(self.configurationColumns.id, primaryKey: .autoincrement)
      t.column(self.configurationColumns.mode)
    })

    try db.run(targets.create(ifNotExists: true) { t in
      t.column(self.targetColumns.id, primaryKey: .autoincrement)
      t.column(self.targetColumns.project)
      t.column(self.targetColumns.target)
    })

    try db.run(sourceFiles.create(ifNotExists: true) { t in
      t.column(self.sourceFileColumns.filename)
      t.column(self.sourceFileColumns.hash)
      t.column(self.sourceFileColumns.configID)
      t.column(self.sourceFileColumns.targetID)
      t.primaryKey(self.sourceFileColumns.filename, self.sourceFileColumns.configID, self.sourceFileColumns.targetID)
      t.foreignKey(
        self.sourceFileColumns.configID,
        references: self.configurations, self.configurationColumns.id)
      t.foreignKey(
        self.sourceFileColumns.targetID,
        references: self.targets, self.targetColumns.id)
    })
  }

  mutating func selectConfiguration(
    mode: OptimizationMode
  ) throws {
    let selectStmnt = self.configurations
      .select(self.configurationColumns.id)
      .where(self.configurationColumns.mode == mode)
    self.configurationId = try self.db.pluck(selectStmnt)?[self.configurationColumns.id]

    if self.configurationId == nil {
      self.configurationId = try self.db.run(
        self.configurations.insert(
          self.configurationColumns.mode <- mode
        )
      )
    }
  }

  /// Select all files of a target
  func files(_ target: TargetRef, artifact artifactType: ArtifactType) throws -> RowIterator {
    let query = self.sourceFiles
      .select(self.sourceFileColumns.filename, self.sourceFileColumns.hash)
      .join(self.targets, on: self.targetColumns.id == self.sourceFileColumns.targetID)
      .where(self.targetColumns.project == target.project)
      .where(self.targetColumns.target == target.target)
      .where(self.sourceFileColumns.artifactType == artifactType)

    return try self.db.prepareRowIterator(query)
  }

  func files(_ dependency: Dependency) throws -> RowIterator {
    try self.files(dependency.library, artifact: .library(dependency.artifact))
  }

  //func files(_ dependency: Dependency) throws -> [String:String] {

  //}

  // TODO: select sources for current configuration, specific target and specific artifact

  // Insert new files
  // Update old files with hash
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

extension ArtifactType: SQLite.Value {
  public typealias Datatype = Int64

  public static var declaredDatatype: String {
    "INT"
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

extension ExecutableArtifactType {
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

extension LibraryArtifactType {
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
