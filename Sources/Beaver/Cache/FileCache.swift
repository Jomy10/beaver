import Foundation
// SQLite does have its own thread-safe implementation
@preconcurrency import SQLite

import timespec
import Platform
import CryptoSwift

// TODO: Store artifacts a target depends on in cache, when changed recompile the target's artifact

/// ```mermaid
/// erDiagram
///
/// File {
/// 	int id
/// 	string filename
/// 	int mtime
/// 	int size
/// 	int ino
/// 	int mode
/// 	int uid
/// 	int gid
/// }
///
/// CSourceFile {
/// 	int fileID
/// 	int configID
/// 	int targetID
/// 	int objectType
/// }
///
/// Configuration {
///   int id
/// 	string mode
/// }
///
/// Target {
/// 	int id
/// 	int project
/// 	int target
/// }
///
/// File ||--|| CSourceFile: fileID
/// CSourceFile }o--|| Configuration: configID
/// CSourceFile }o--|| Target: targetID
/// ```
struct FileCache: Sendable {
  let db: Connection
  let files: FileTable
  let csourceFiles: CSourceFileTable
  let configurations: ConfigurationTable
  let targets: TargetTable
  let globalConfigurations: GlobalConfigurationTable
  var globalConfiguration: (buildId: Int, env: Data)?

  var configurationId: Int64? = nil

  init(
    cacheFile: URL,
    buildId: Int = BeaverConstants.buildId,
    /// Compare the environment variables using by converting the dictionary as bytes to an md5 hash
    env: Data = try! Data(PropertyListSerialization.data(
      fromPropertyList: ProcessInfo.processInfo.arguments,
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

    try self.files.createIfNotExists(self.db)
    try self.configurations.createIfNotExists(self.db)
    try self.targets.createIfNotExists(self.db)
    try self.csourceFiles.createIfNotExists(self.db)
    try self.globalConfigurations.createIfNotExists(self.db)

    if let globConf = try db.pluck(self.globalConfigurations.table.limit(1)) {
      self.globalConfiguration = (
        buildId: globConf[self.globalConfigurations.buildId.unqualified],
        env: globConf[self.globalConfigurations.environment.unqualified]
      )

      if self.globalConfiguration!.buildId != buildId {
        try self.db.run(self.globalConfigurations.table
          .update(self.globalConfigurations.buildId.unqualified <- buildId))
          // TODO: rebuild the database
        MessageHandler.info("Previous artifacts were built with a different version of Beaver. Objects will be rebuilt.")
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

  func getTargetIfExists(_ target: TargetRef) throws -> Int64? {
    guard let row = (try db.pluck(self.targets.table.select(self.targets.id.qualified)
      .where(self.targets.project.qualified == target.project)
      .where(self.targets.target.qualified == target.target))
    ) else {
      return nil
    }
    return row[self.targets.id.unqualified]
  }

  /// Get the id for the specified target
  func getTarget(_ target: TargetRef) throws -> Int64 {
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

  // try db.run(users.insert(or: .replace, email <- "alice@mac.com", name <- "Alice B."))
  // INSERT OR REPLACE INTO "users" ("email", "name") VALUES ('alice@mac.com', 'Alice B.')

  struct NoConfigurationSelected: Error {}

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
    try db.run(inputFiles.table.insertMany(files.map { [inputFiles.filename.unqualified <- $0.absoluteURL.path] }))

    guard let configId = self.configurationId else {
      throw NoConfigurationSelected()
    }
    let targetId = try self.getTarget(target)
    let objectType = artifactType.cObjectType!

    // TODO: with
    let filesStmnt = try self.db.run("""
      select
        \(inputFiles.filename.qualified),
        \(self.files.id.unqualified),
        \(self.files.mtime.unqualified),
        \(self.files.size.unqualified),
        \(self.files.inodeNumber.unqualified),
        \(self.files.fileMode.unqualified),
        \(self.files.ownerUid.unqualified),
        \(self.files.ownerGid.unqualified)
      from "\(inputFiles.tableName)"
      left outer join (
        select
          \(self.files.filename.qualified),
          \(self.files.id.unqualified),
          \(self.files.mtime.unqualified),
          \(self.files.size.unqualified),
          \(self.files.inodeNumber.unqualified),
          \(self.files.fileMode.unqualified),
          \(self.files.ownerUid.unqualified),
          \(self.files.ownerGid.unqualified)
        from File
        inner join CSourceFile on \(self.csourceFiles.fileId.qualified) = \(self.files.id.qualified)
                              and \(self.csourceFiles.configId.qualified) = ?
                              and \(self.csourceFiles.targetId.qualified) = ?
                              and \(self.csourceFiles.objectType.qualified) = ?
      ) sub on sub.filename = \(inputFiles.filename.qualified)
      """,
      configId.datatypeValue,
      targetId.datatypeValue,
      objectType.datatypeValue
    )

    var updateValues: [(Int64?, [Setter])] = []
    var returnValue: [Result] = []
    var error: (any Error)? = nil
    do {
      for fileStmnt in filesStmnt {
        let file: FileChecker.File = (
          filename: fileStmnt[0]! as! String,
          id: fileStmnt[1].map { $0 as! Int64 },
          mtime: fileStmnt[2].map { $0 as! Int64 },
          size: fileStmnt[3].map { $0 as! Int64 },
          ino: try fileStmnt[4].map { try UInt64.fromDatatypeValue(($0 as! any SQLite.Number) as! Int64) },
          mode: try fileStmnt[5].map { try UInt64.fromDatatypeValue(($0 as! any SQLite.Number) as! Int64) },
          uid: try fileStmnt[6].map { try UInt64.fromDatatypeValue(($0 as! any SQLite.Number) as! Int64) },
          gid: try fileStmnt[7].map { try UInt64.fromDatatypeValue(($0 as! any SQLite.Number) as! Int64) }
        )
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

  /// Returns false if nothing had to be removed
  @discardableResult
  func removeTarget(target: TargetRef) throws -> Bool {
    guard let targetId = try self.getTargetIfExists(target) else {
      return false
    }
    let files = try (self.db.prepareRowIterator(self.files.table
      .select(self.files.id.qualified)
      .join(self.csourceFiles.table, on: self.csourceFiles.fileId.qualified == self.files.id.qualified)))
        .map { row in
          row[self.files.id.unqualified]
        }
    if files.count > 0 {
      try self.db.run(self.files.table
        .where(files.contains(self.files.id.qualified))
        .delete())
    }
    try self.db.run(self.csourceFiles.table
      .where(self.csourceFiles.targetId.unqualified == targetId)
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
  //static let filename = SQLite.Expression<String>("filename")
  //static let id = SQLite.Expression<Int64?>("id")
  //static let mtime = SQLite.Expression<Int64?>("mtime")
  //static let size = SQLite.Expression<Int64?>("size")
  //static let inodeNumer = SQLite.Expression<UInt64?>("ino")
  //static let fileMode = SQLite.Expression<UInt64?>("mode")
  //static let ownerUid = SQLite.Expression<UInt64?>("uid")
  //static let ownerGid = SQLite.Expression<UInt64?>("gid")
  typealias File = (filename: String, id: Int64?, mtime: Int64?, size: Int64?, ino: UInt64?, mode: UInt64?, uid: UInt64?, gid: UInt64?)

  /// Returns wether the file has changed and the new `stat` of the file
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
