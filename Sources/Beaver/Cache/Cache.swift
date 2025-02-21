import Foundation
import Utils
import CryptoSwift
@preconcurrency import SQLite
import csqlite3_glue

// TODO: implement
struct Cache: Sendable {
  let db: Connection
  var configId: Int64? = nil

  // TODO: global configuration
  init(
    _ cacheFile: URL,
    buildId: Int,
    env: Data = try! Data(PropertyListSerialization.data(
      fromPropertyList: ProcessInfo.processInfo.environment
        .map { k, v in (k, v) }
        .sorted { a, b in a.0 > b.0 }
        .map { (k, v) in NSString(string: "\(k):\(v)") },
      format: .binary,
      options: 0
    ).bytes.md5()),
    clean: inout Bool
  ) throws {
    //self.db = try Connection(.uri(cacheFile.path, parameters: [.mode(.readWriteCreate), .nolock(true)])) // causes DISK I/O Error
    //// sqlite doesn't make the database file writable
    //if !FileManager.default.isWritable(at: cacheFile) {
    //  try FileManager.default.setWritable(at: cacheFile)
    //}
    self.db = try Connection(cacheFile.path)
    self.db.busyTimeout = 4

    print("Checking global cache...")
    try GlobalCache.createIfNotExists(self.db)
    if try GlobalCache.changed(buildId: buildId, env: env, self.db) {
      Self.reset(self.db)
      try GlobalCache.createIfNotExists(self.db)
      try GlobalCache.insert(buildId: buildId, env: env, self.db)
      clean = true
    }

    print("Creating tables...")
    try ConfigurationCache.createIfNotExists(self.db)
    try FileCache.createIfNotExists(self.db)
    try CMakeProjectCache.createIfNotExists(self.db)
    try CMakeFile.createIfNotExists(self.db)
    try CacheVariable.createIfNotExists(self.db)
    try CustomFile.createIfNotExists(self.db)
    assert(ConfigurationCache.tableName == "Configuration")
    print(ConfigurationCache.table.expression)

    self.db.trace { msg in
      MessageHandler.trace(msg, context: .sql)
    }
  }

  mutating func selectConfiguration(mode: OptimizationMode) throws {
    if let config = try self.db.pluck(ConfigurationCache.table
      .select(ConfigurationCache.Columns.id.qualified)
      .where(ConfigurationCache.Columns.mode.qualified == mode)
    ) {
      self.configId = config[ConfigurationCache.Columns.id.qualified]
    } else {
      self.configId = try self.db.run(ConfigurationCache.table
        .insert([
          ConfigurationCache.Columns.mode.unqualified <- mode
        ]))
    }
  }

  static func reset(_ db: Connection) {
    sqliteglue_db_config_reset_database(db.handle, 1, 0)
    sqlite3_exec(db.handle, "VACUUM", nil, nil, nil)
    sqliteglue_db_config_reset_database(db.handle, 0, 0)
  }

  func shouldReconfigureCMakeProject(_ cmakeBaseDir: URL) throws -> Bool {
    guard let project = try CMakeProjectCache.get(path: cmakeBaseDir, self.db) else {
      return true
    }
    var anyChanged = false
    for file in try self.db.prepare(CMakeFile.table
      .select(
        FileCache.Columns.filename.qualified,
        FileCache.Columns.checkId.qualified,
        FileCache.Columns.mtime.qualified,
        FileCache.Columns.size.qualified,
        FileCache.Columns.ino.qualified,
        FileCache.Columns.mode.qualified,
        FileCache.Columns.uid.qualified,
        FileCache.Columns.gid.qualified
      )
      .join(.inner, FileCache.table, on: FileCache.Columns.filename.qualified == CMakeFile.Columns.file.qualified)
      .where(CMakeFile.Columns.cmakeProjectId.qualified == project.id)
    ) {
      let fcache = try FileCache(row: file)
      let (changed, attrs) = try FileChecker.fileChanged(fcache)
      if changed {
        try FileCache.update(FileCache(file: fcache.filename, fromAttrs: attrs), self.db)
        anyChanged = true
      }
    }
    //let project: CMakeProjectCache = if let project = try CMakeProject.get(path: cmakeBaseDir, db: self.db) {
    //  project
    //} else {
    //  CMakeProjectCache(id: try self.db.run(CMakeProject(cmakeBaseDir).setter), path: cmakeBaseDir)
    //}
    return anyChanged
  }

  func storeCMakeFiles(dir cmakeBaseDir: URL, _ files: [URL]) throws {
    let project: CMakeProjectCache
    if let _project = try CMakeProjectCache.get(path: cmakeBaseDir, self.db) {
      project = _project
    } else {
      let projectId = try CMakeProjectCache.insertNew(cmakeBaseDir, self.db)
      project = CMakeProjectCache(id: projectId, path: cmakeBaseDir)
    }

    let tmpTable = try TmpFile.createTemporary(self.db)
    let tmpFileSetters = files.map { file in
      TmpFile(file: file).setter
    }
    try self.db.run(tmpTable.insertMany(tmpFileSetters))

    for file in try self.db.prepare(tmpTable
      .join(.leftOuter, CMakeFile.table, on: CMakeFile.Columns.file.qualifiedOptional == tmpTable[TmpFile.Columns.file.unqualified]
                                          && CMakeFile.Columns.cmakeProjectId.qualifiedOptional == project.id)
    ) {
      if file[CMakeFile.Columns.file.qualifiedOptional] == nil {
        let path = file[tmpTable[TmpFile.Columns.file.unqualified]]
        let attrs = try FileChecker.fileAttrs(file: path)
        let newCMakeFile = CMakeFile(cmakeProjectId: project.id, file: path)
        if try !FileCache.exists(file[tmpTable[TmpFile.Columns.file.unqualified]], self.db) {
          let newFile = FileCache(file: path, fromAttrs: attrs)
          _ = try newFile.insert(self.db)
        }
        _ = try newCMakeFile.insert(self.db)
      }
    }
  }

  // User-defined //

  func fileChanged(file: URL, context: String) throws -> Bool {
    if let fileRow = try self.db.pluck(CustomFile.table
      .join(.inner, FileCache.table, on: FileCache.Columns.filename.qualified == CustomFile.Columns.file.qualified)
      .where(CustomFile.Columns.file.qualified == file
          && CustomFile.Columns.context.qualified == context)
    ) {
      let file = try FileCache(row: fileRow)
      let oldCheckId = fileRow[CustomFile.Columns.checkId.qualified]

      let (changed, attrs) = try FileChecker.fileChanged(file)
      if changed {
        let fileCache = FileCache(file: file.filename, fromAttrs: attrs)
        try FileCache.update(fileCache, self.db)
        try self.db.run(FileCache.table
          .where(CustomFile.Columns.file.qualified == file.filename
              && CustomFile.Columns.context.qualified == context)
          .update(FileCache.Columns.checkId.qualified <- file.checkId))
          return true
      }

      if file.checkId != oldCheckId {
        try self.db.run(FileCache.table
        .where(CustomFile.Columns.file.qualified == file.filename
              && CustomFile.Columns.context.qualified == context)
          .update(FileCache.Columns.checkId.qualified <- file.checkId))
          return true
      } else {
        return false
      }
    } else {
      let fileCache: FileCache = try FileCache.getOrInsert(file, self.db)

      let customFile = CustomFile(file: file, context: context, checkId: fileCache.checkId)
      try customFile.insert(self.db)

      return true
    }
  }

  func getVar(name: String) throws -> CacheVarVal {
    try CacheVariable.getValue(name: name, self.db) ?? .none
  }

  func setVar(name: String, value: CacheVarVal) throws {
    try CacheVariable.updateOrInsert(CacheVariable(name: name, val: value), self.db)
  }
}

public enum CacheVarVal {
  case string(String)
  case int(Int)
  case double(Double)
  case bool(Bool)
  /// All non-existant cache variables are implicitly nil
  case none
}
