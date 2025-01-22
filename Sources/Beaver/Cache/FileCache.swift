import Foundation
// SQLite does have its own thread-safe implementation
@preconcurrency import SQLite

import timespec
import Platform
import CryptoSwift

/// ![schema](/docs/internal/Cache.md)
struct FileCache: Sendable {
  let db: Connection
  let files: FileTable
  let csourceFiles: CSourceFileTable
  let configurations: ConfigurationTable
  let targets: TargetTable
  let globalConfigurations: GlobalConfigurationTable
  var globalConfiguration: (buildId: Int, env: Data)?
  let dependencyFiles: DependencyFileTable

  var configurationId: Int64? = nil

  enum CacheError: Swift.Error {
    case noInputFiles
    case noConfigurationSelected
  }

  init(
    cacheFile: URL,
    buildId: Int = BeaverConstants.buildId,
    /// Compare the environment variables using by converting the dictionary as bytes to an md5 hash
    env: Data = try! Data(PropertyListSerialization.data(
      fromPropertyList: ProcessInfo.processInfo.environment
        .map { k, v in (k, v) }
        .sorted { a, b in a.0 > b.0 }
        .map { (k, v) in NSString(string: "\(k):\(v)") },
      format: .binary,
      options: 0
    ).bytes.md5())
  ) throws {
    self.db = try Connection(cacheFile.path)
    self.files = FileTable()
    self.csourceFiles = CSourceFileTable()
    self.configurations = ConfigurationTable()
    self.targets = TargetTable()
    self.globalConfigurations = GlobalConfigurationTable()
    self.globalConfiguration = nil
    self.dependencyFiles = DependencyFileTable()

    try self.files.createIfNotExists(self.db)
    try self.configurations.createIfNotExists(self.db)
    try self.targets.createIfNotExists(self.db)
    try self.csourceFiles.createIfNotExists(self.db)
    try self.globalConfigurations.createIfNotExists(self.db)
    try self.dependencyFiles.createIfNotExists(self.db)

    if let globConf = try db.pluck(self.globalConfigurations.table.limit(1)) {
      self.globalConfiguration = (
        buildId: globConf[self.globalConfigurations.buildId.unqualified],
        env: globConf[self.globalConfigurations.environment.unqualified]
      )

      if self.globalConfiguration!.buildId != buildId {
        try self.db.run(self.globalConfigurations.table
          .update(self.globalConfigurations.buildId.unqualified <- buildId))
          // TODO: rebuild the database
        MessageHandler.info("Previous artifacts were built with a different version of Beaver. Cache has been reset.")
        try self.reset()
      }

      if self.globalConfiguration!.env.bytes != env.bytes {
        try self.db.run(self.globalConfigurations.table
          .update(self.globalConfigurations.environment.unqualified <- env))
        MessageHandler.info("Environment variables were changed since last invocation. Cache has been reset.")
        try self.reset()
      }
    } else {
      try self.db.run(self.globalConfigurations.table
        .insert(
          self.globalConfigurations.buildId.unqualified <- buildId,
          self.globalConfigurations.environment.unqualified <- env
        ))
    }

    #if DEBUG
    self.db.trace { msg in
      MessageHandler.trace(msg, context: .sql)
    }
    #endif
  }

  mutating func selectConfiguration(
    mode: OptimizationMode
  ) throws {
    let selectStmnt = self.configurations.table
      .select(self.configurations.id.qualified)
      .where(self.configurations.mode.qualified == mode)
    self.configurationId = try self.db.pluck(selectStmnt)?[self.configurations.id.unqualified]

    if self.configurationId == nil {
      self.configurationId = try self.db.run(
        self.configurations.table.insert(
          self.configurations.mode.unqualified <- mode
        )
      )
    }
  }

  // TODO: async lock?
  /// Lock when retrieving a target so that no double targets are created
  let targetRetrievalLock: NSLock = NSLock()

  func getTargetIfExists(_ target: TargetRef) throws -> Int64? {
    guard let row = (try db.pluck(self.targets.table.select(self.targets.id.qualified)
      .where(self.targets.project.qualified == target.project)
      .where(self.targets.target.qualified == target.target))
    ) else {
      MessageHandler.debug("Couldn't find \(target)")
      return nil
    }
    return row[self.targets.id.unqualified]
  }

  /// Get the id for the specified target
  func getTarget(_ target: TargetRef) throws -> Int64 {
    try self.targetRetrievalLock.withLock {
      let targetId = try self.getTargetIfExists(target)
      if let targetId = targetId {
        return targetId
      } else {
        return try db.run(self.targets.table.insert([
          self.targets.project.unqualified <- target.project,
          self.targets.target.unqualified <- target.target
        ]))
      }
    }
  }

  // try db.run(users.insert(or: .replace, email <- "alice@mac.com", name <- "Alice B."))
  // INSERT OR REPLACE INTO "users" ("email", "name") VALUES ('alice@mac.com', 'Alice B.')

  func loopSourceFiles<Result>(
    _ files: borrowing [URL],
    target: TargetRef,
    /// TODO: handle error
    artifact artifactType: ArtifactType,
    _ cb: (consuming URL, Bool) async throws -> Result
  ) async throws -> [Result] {
    // Create a temporary table to hold our files
    let inputFiles = TempInputFileTable()
    try inputFiles.create(self.db)
    try inputFiles.insert(files, self.db)
    //try db.run(inputFiles.table.insertMany(files.map { [inputFiles.filename.unqualified <- $0.absoluteURL.path] }))


    guard let configId = self.configurationId else {
      throw CacheError.noConfigurationSelected()
    }
    let targetId = try self.getTarget(target)
    let objectType = artifactType.cObjectType!

    let subTable = Table("sub")

    /*
      select
        #inputFiles.filename,
        file.id,
        file.mtime,
        file.size,
        file.ino,
        file.uid,
        file.gid
      from #inputFiles
      left outer join (
        select
          file.filename,
          file.id,
          file.mtime,
          file.size,
          file.ino
          file.uid,
          file.gid
        from file
        inner join cSourceFile c on c.fileID = file.id
                                and c.configID = `configID`
                                and c.targetID = `targetID`
                                and c.objectType = `objectType`
      ) sub on sub.filename = #inputFile.filename
    */

    let subQuery = self.files.table
      .select(
        self.files.filename.qualified,
        self.files.id.qualified,
        self.files.mtime.qualified,
        self.files.size.qualified,
        self.files.inodeNumber.qualified,
        self.files.fileMode.qualified,
        self.files.ownerUid.qualified,
        self.files.ownerGid.qualified
      )
      .join(
        .inner,
        self.csourceFiles.table,
        on:  self.csourceFiles.fileId.qualified == self.files.id.qualified
          && self.csourceFiles.configId.qualified == configId
          && self.csourceFiles.targetId.qualified == targetId
          && self.csourceFiles.objectType.qualified == objectType
      )

    let filesQuery = inputFiles.table
      .select(
        inputFiles.filename.qualified,
        subTable[self.files.id.unqualified],
        subTable[self.files.mtime.unqualified],
        subTable[self.files.size.unqualified],
        subTable[self.files.inodeNumber.unqualified],
        subTable[self.files.fileMode.unqualified],
        subTable[self.files.ownerUid.unqualified],
        subTable[self.files.ownerGid.unqualified]
      )
      .with(subTable, as: subQuery)
      .join(.leftOuter, subTable, on: subTable[self.files.filename.unqualified] == inputFiles.filename.qualified)

    var updateValues: [(Int64?, [Setter])] = []
    var returnValue: [Result] = []
    var error: (any Error)? = nil
    do {
      //for fileStmnt in filesStmnt {
      for row in try self.db.prepare(filesQuery) {
        //let file: FileChecker.File = (
        //  filename: fileStmnt[0]! as! String,
        //  id: fileStmnt[1].map { $0 as! Int64 },
        //  mtime: fileStmnt[2].map { $0 as! Int64 },
        //  size: fileStmnt[3].map { $0 as! Int64 },
        //  ino: try fileStmnt[4].map { try UInt64.fromDatatypeValue(($0 as! any SQLite.Number) as! Int64) },
        //  mode: try fileStmnt[5].map { try UInt64.fromDatatypeValue(($0 as! any SQLite.Number) as! Int64) },
        //  uid: try fileStmnt[6].map { try UInt64.fromDatatypeValue(($0 as! any SQLite.Number) as! Int64) },
        //  gid: try fileStmnt[7].map { try UInt64.fromDatatypeValue(($0 as! any SQLite.Number) as! Int64) }
        //)
        let file: FileChecker.File = FileChecker.fileFromRow(row)
        let filename: String = file.filename
        let (changed, attrs) = try FileChecker.fileChanged(file: file)

        MessageHandler.trace("\(filename) (\(changed ? "changed" : "not changed"))")
        returnValue.append(try await cb(URL(filePath: filename), changed))
        if changed {
          let fileId = file.id
          updateValues.append((
            fileId,
            [
              self.files.filename.unqualified <- filename,
              self.files.mtime.unqualified <- Int64(timespec_to_ms(attrs.st_mtimespec)),
              self.files.size.unqualified <- Int64(attrs.st_size),
              self.files.inodeNumber.unqualified <- UInt64(attrs.st_ino),
              self.files.fileMode.unqualified <- UInt64(attrs.st_mode),
              self.files.ownerUid.unqualified <- UInt64(attrs.st_uid),
              self.files.ownerGid.unqualified <- UInt64(attrs.st_gid)
            ]
          ))
        }
      }
    } catch let _error {
      error = _error
    }

    // Update all files that were built successfully
    for (fileColumnId, setter) in updateValues {
      if let fileColumnId = fileColumnId {
        try db.run(self.files.table.where(self.files.id.unqualified == fileColumnId).update(setter))
      } else {
        let id = try db.run(self.files.table.insert(setter))
        try db.run(self.csourceFiles.table.insert([
          self.csourceFiles.fileId.unqualified <- id,
          self.csourceFiles.configId.unqualified <- configId,
          self.csourceFiles.targetId.unqualified <- targetId,
          self.csourceFiles.objectType.unqualified <- objectType
        ]))
      }
    }

    // throw error if any occured
    if let error = error {
      throw error
    }

    return returnValue
  }

  /// Returns wether any of the dependency files have changed, or if new files have been added.
  /// Updates the cache.
  func dependencyFilesChanged(
    currentFiles: borrowing [URL],
    target: TargetRef,
    forBuildingArtifact artifactType: ArtifactType
  ) throws -> Bool {
    guard let configId = self.configurationId else {
      throw CacheError.noConfigurationSelected()
    }
    let targetId = try self.getTarget(target)

    let subTable = Table("sub_files")

    var subQuery: Table
    if currentFiles.count == 0 {
      subQuery = self.dependencyFiles.table
        .select(self.files.id.qualified)
    } else {
      subQuery = self.dependencyFiles.table
        .select(
          self.files.filename.qualified,
          self.files.id.qualified,
          self.files.mtime.qualified,
          self.files.size.qualified,
          self.files.inodeNumber.qualified,
          self.files.fileMode.qualified,
          self.files.ownerUid.qualified,
          self.files.ownerGid.qualified
        )
    }

    subQuery = subQuery
      .join(.inner, self.files.table, on: self.dependencyFiles.fileId.qualified == self.files.id.qualified)
      .where(self.dependencyFiles.configId.qualified == configId)
      .where(self.dependencyFiles.targetId.qualified == targetId)
      .where(self.dependencyFiles.artifactType.qualified == artifactType)

    if currentFiles.count == 0 {
      let count = try db.scalar(subQuery.count)
      return count != currentFiles.count
    }

    let inputFiles = TempInputFileTable()
    try inputFiles.create(self.db)
    try inputFiles.insert(currentFiles, self.db)

    let filesQuery = inputFiles.table
      .select(
        inputFiles.filename.qualified,
        subTable[self.files.id.unqualified],
        subTable[self.files.mtime.unqualified],
        subTable[self.files.size.unqualified],
        subTable[self.files.inodeNumber.unqualified],
        subTable[self.files.fileMode.unqualified],
        subTable[self.files.ownerUid.unqualified],
        subTable[self.files.ownerGid.unqualified]
      )
      .with(subTable, as: subQuery)
      .join(.leftOuter, subTable, on: subTable[self.files.filename.unqualified] == inputFiles.filename.qualified)

    var anyChanged = false
    for row in try self.db.prepare(filesQuery) {
      let file = FileChecker.fileFromRow(row)
      let filename = file.filename
      let (changed, attrs) = try FileChecker.fileChanged(file: file)

      MessageHandler.trace("Artifact \(filename) (\(changed ? "changed" : "not changed"))")
      if changed {
        anyChanged = true
        if let id = file.id {
          try self.db.run(self.files.table
            .where(self.files.id.qualified == id)
            .update([
              self.files.mtime.unqualified <- Int64(timespec_to_ms(attrs.st_mtimespec)),
              self.files.size.unqualified <- Int64(attrs.st_size),
              self.files.inodeNumber.unqualified <- UInt64(attrs.st_ino),
              self.files.fileMode.unqualified <- UInt64(attrs.st_mode),
              self.files.ownerUid.unqualified <- UInt64(attrs.st_uid),
              self.files.ownerGid.unqualified <- UInt64(attrs.st_gid),
            ])
          )
        } else {
          let id = try self.db.run(self.files.table
            .insert([
              self.files.filename.unqualified <- filename,
              self.files.mtime.unqualified <- Int64(timespec_to_ms(attrs.st_mtimespec)),
              self.files.size.unqualified <- Int64(attrs.st_size),
              self.files.inodeNumber.unqualified <- UInt64(attrs.st_ino),
              self.files.fileMode.unqualified <- UInt64(attrs.st_mode),
              self.files.ownerUid.unqualified <- UInt64(attrs.st_uid),
              self.files.ownerGid.unqualified <- UInt64(attrs.st_gid),
            ])
          )
          try self.db.run(self.dependencyFiles.table
            .insert([
              self.dependencyFiles.fileId.unqualified <- id,
              self.dependencyFiles.configId.unqualified <- configId,
              self.dependencyFiles.targetId.unqualified <- targetId,
              self.dependencyFiles.artifactType.unqualified <- artifactType
            ]))
        }
      }
    }

    return anyChanged
  }

  /// Returns false if nothing had to be removed
  @discardableResult
  func removeTarget(target: TargetRef) throws -> Bool {
    guard let targetId = try self.getTargetIfExists(target) else {
      return false
    }
    let files = (try (self.db.prepareRowIterator(self.files.table
      .select(self.files.id.qualified)
      .join(self.csourceFiles.table, on: self.csourceFiles.fileId.qualified == self.files.id.qualified)))
        .map { row in
          row[self.files.id.unqualified]
        })
      + (try self.db.prepareRowIterator(self.files.table
          .select(self.files.id.qualified)
          .join(self.dependencyFiles.table, on: self.dependencyFiles.fileId.qualified == self.files.id.qualified))
            .map { row in
              row[self.files.id.unqualified]
            })
    if files.count > 0 {
      try self.db.run(self.files.table
        .where(files.contains(self.files.id.qualified))
        .delete())
    }
    try self.db.run(self.csourceFiles.table
      .where(self.csourceFiles.targetId.unqualified == targetId)
      .delete())
    try self.db.run(self.dependencyFiles.table
      .where(self.dependencyFiles.targetId.unqualified == targetId)
      .delete())
    try self.db.run(self.targets.table
      .where(self.targets.id.unqualified == targetId)
      .delete())

    return true
  }

  func reset() throws {
    try self.db.run(self.files.table.delete())
    try self.db.run(self.csourceFiles.table.delete())
    try self.db.run(self.configurations.table.delete())
    try self.db.run(self.targets.table.delete())
  }
}

// Stat docs:
// - https://www.mkssoftware.com/docs/man5/struct_stat.5.asp
// - https://learn.microsoft.com/en-us/cpp/c-runtime-library/reference/stat-functions?view=msvc-170
struct StatError: Error, CustomStringConvertible {
  let filename: String
  let code: Int32

  var description: String {
    let errMsg = switch (self.code) {
      case EACCES: "Search permission is denied for a component of the path prefix."
      case EIO: "An error occurred while reading from the file system."
      case ELOOP: "A loop exists in symbolic links encountered during resolution of the path argument."
      case ENAMETOOLONG: "The length of the pat argument exceeds {PATH_MAX} or a pathname component is longer than {NAME_MAX}."
      case ENOENT: "A component of path does not name an existing file or path is an empty string."
      case ENOTDIR: "A component of the path prefix is not a directory."
      case EOVERFLOW: "The file size in bytes or the number of blocks allocated to the file or the file serial number cannot be represented correctly in the structure pointed to by buf."
      default: String(cString: strerror(self.code)!)
    }
    return "Error executing `stat` for file '\(self.filename)': \(errMsg)"
  }
}


/// Checks if a file has changed
///
/// This approach is similar to `redo` as outlined in [this article](https://apenwarr.ca/log/20181113)
/// (see redo: mtime dependencies done right)
struct FileChecker {
  typealias File = (filename: String, id: Int64?, mtime: Int64?, size: Int64?, ino: UInt64?, mode: UInt64?, uid: UInt64?, gid: UInt64?)

  static func fileFromRow(_ row: Row) -> File {
    (
      filename: row[SQLite.Expression<String>("filename")],
      id: row[SQLite.Expression<Int64?>("id")],
      mtime: row[SQLite.Expression<Int64?>("mtime")],
      size: row[SQLite.Expression<Int64?>("size")],
      ino: row[SQLite.Expression<UInt64?>("ino")],
      mode: row[SQLite.Expression<UInt64?>("mode")],
      uid: row[SQLite.Expression<UInt64?>("uid")],
      gid: row[SQLite.Expression<UInt64?>("gid")]
    )
  }

  /// Returns wether the file has changed and the new `stat` of the file.
  /// Also returns true if the file has not been cached before (e.g. it is a new file)
  static func fileChanged(file: Self.File) throws -> (Bool, stat) {
    let filename = file.filename

    var attrs = stat()
    try filename.withCString({ str in
      if stat(str, &attrs) == -1 {
        if errno == EOVERFLOW {
          MessageHandler.print("An error occured in `stat` that might be solved by using stat64, please open an issue or fix this by opening a pull request for Beaver at https://github.com/Jomy10/Beaver")
        }
        throw StatError(filename: filename, code: errno)
      }
    })

    // File hasn't been cached yet
    if file.id == nil {
      return (true, attrs)
    }

    if let mtime = file.mtime {
      let newMtime = Int64(timespec_to_ms(attrs.st_mtimespec))
      if mtime != newMtime { return (true, attrs) }
    } else {
      return (true, attrs)
    }

    if let size = file.size {
      if size != attrs.st_size { return (true, attrs) }
    } else {
      return (true, attrs)
    }

    if let ino = file.ino {
      if ino != attrs.st_ino { return (true, attrs) }
    } else {
      return (true, attrs)
    }

    if let mode = file.mode {
      if mode != attrs.st_mode { return (true, attrs) }
    } else {
      return (true, attrs)
    }

    if let uid = file.uid {
      if uid != attrs.st_uid { return (true, attrs) }
    } else {
      return (true, attrs)
    }

    if let gid = file.gid {
      if gid != attrs.st_gid { return (true, attrs) }
    } else {
      return (true, attrs)
    }

    return (false, attrs) // All checks passed; file hasn't changed
  }
}
