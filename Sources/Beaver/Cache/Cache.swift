import Foundation
import Utils
@preconcurrency import SQLite
import csqlite3_glue

// TODO: implement
struct Cache: Sendable {
  let db: Connection
  var configId: Int64? = nil

  // TODO: global configuration
  init(_ cacheFile: URL) throws {
    self.db = try Connection(cacheFile.path)

    try ConfigurationCache.createIfNotExists(self.db)
    try FileCache.createIfNotExists(self.db)
    try CMakeProjectCache.createIfNotExists(self.db)
    try CMakeFile.createIfNotExists(self.db)
    try CacheVariable.createIfNotExists(self.db)

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

  func shouldReconfigureCMakeProject(_ cmakeBaseDir: URL) throws -> Bool {
    guard let project = try CMakeProjectCache.get(path: cmakeBaseDir, self.db) else {
      return true
    }
    var anyChanged = false
    for file in try self.db.prepare(CMakeFile.table
      .select(
        FileCache.Columns.filename.qualifiedOptional,
        FileCache.Columns.mtime.qualifiedOptional,
        FileCache.Columns.size.qualifiedOptional,
        FileCache.Columns.ino.qualifiedOptional,
        FileCache.Columns.mode.qualifiedOptional,
        FileCache.Columns.uid.qualifiedOptional,
        FileCache.Columns.gid.qualifiedOptional
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
        let newFile = FileCache(file: path, fromAttrs: attrs)
        _ = try newFile.insert(self.db)
        _ = try newCMakeFile.insert(self.db)
      }
    }
  }

  // User-defined //

  func fileChanged(file: URL, context: String) throws -> Bool {
    fatalError("TODO")
  }

  func getVar(name: String) throws -> CacheVarVal {
    try CacheVariable.getValue(name: name, self.db) ?? .none
  }

  func setVar(name: String, value: CacheVarVal) throws {
    try CacheVariable.updateOrInsert(value, self.db)
  }

  func configChanged(context: String) throws -> Bool {
    fatalError("TODO")
  }
}

public enum CacheVarVal {
  case string(String)
  case int(Int)
  case double(Double)
  case bool(Bool)
  /// All non-existant cache variables are implicitly nil
  case none

  //func asEntry(withName name: String) -> CustomVariable {
  //  switch (self) {
  //    case .string(let s): CustomVariable(name: name, strVal: s)
  //    case .int(let i): CustomVariable(name: name, intVal: i)
  //    case .double(let d): CustomVariable(name: name, doubleVal: d)
  //    case .bool(let b): CustomVariable(name: name, boolVal: b)
  //    case .none: CustomVariable(name: name)
  //  }
  //}

  //init(fromEntry entry: CustomVariable) {
  //  if let strVal = entry.strVal {
  //    self = .string(strVal)
  //  } else if let intVal = entry.intVal {
  //    self = .int(intVal)
  //  } else if let doubleVal = entry.doubleVal {
  //    self = .double(doubleVal)
  //  } else if let boolVal = entry.boolVal {
  //    self = .bool(boolVal)
  //  } else {
  //    self = .none
  //  }
  //}
}
