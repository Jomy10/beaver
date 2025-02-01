import Foundation
// SQLite does have its own thread-safe implementation
@preconcurrency import SQLite

import timespec
import Platform
import CryptoSwift
import Utils

/// ![schema](/docs/internal/Cache.md)
struct FileCache: Sendable {
  var db: Connection
  let files: FileTable
  let csourceFiles: CSourceFileTable
  let configurations: ConfigurationTable
  let targets: TargetTable
  let targetCaches: TargetCacheTable
  let targetDependencyCaches: TargetDependencyCacheTable
  let globalConfigurations: GlobalConfigurationTable
  var globalConfiguration: (buildId: Int, env: Data)?
  let dependencyFiles: DependencyFileTable
  let customFiles: CustomFileTable
  let outputFiles: OutputFileTable
  let cmakeProjects: CMakeProjectTable
  let cmakeFiles: CMakeFileTable

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
    self.targetCaches = TargetCacheTable()
    self.targetDependencyCaches = TargetDependencyCacheTable()
    self.globalConfigurations = GlobalConfigurationTable()
    self.globalConfiguration = nil
    self.dependencyFiles = DependencyFileTable()
    self.customFiles = CustomFileTable()
    self.outputFiles = OutputFileTable()
    self.cmakeProjects = CMakeProjectTable()
    self.cmakeFiles = CMakeFileTable()

    if let globConf = try? db.pluck(self.globalConfigurations.table.limit(1)) {
      self.globalConfiguration = (
        buildId: globConf[self.globalConfigurations.buildId.unqualified],
        env: globConf[self.globalConfigurations.environment.unqualified]
      )

      var resetGlobalConfig = false

      if self.globalConfiguration!.buildId != buildId {
        //try self.db.run(self.globalConfigurations.table
        //  .update(self.globalConfigurations.buildId.unqualified <- buildId))
        try FileManager.default.removeItem(at: cacheFile)
        MessageHandler.info("Previous artifacts were built with a different version of Beaver. Cache has been reset.") // TODO: cache reset context
        self.db = try Connection(cacheFile.path)
        resetGlobalConfig = true
      }

      if self.globalConfiguration!.env.bytes != env.bytes {
        //try self.db.run(self.globalConfigurations.table
        //  .update(self.globalConfigurations.environment.unqualified <- env))
        if !resetGlobalConfig {
          try FileManager.default.removeItem(at: cacheFile)
          MessageHandler.info("Environment variables were changed since last invocation. Cache has been reset.")
          self.db = try Connection(cacheFile.path)
        }
      }

      try self.createdb()

      if resetGlobalConfig {
        try self.db.run(self.globalConfigurations.table
          .insert([
            self.globalConfigurations.environment.unqualified <- env,
            self.globalConfigurations.buildId.unqualified <- buildId
          ]))
      }
    } else {
      try self.createdb()

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

  func createdb() throws {
    try self.files.createIfNotExists(self.db)
    try self.configurations.createIfNotExists(self.db)
    try self.targets.createIfNotExists(self.db)
    try self.targetCaches.createIfNotExists(self.db)
    try self.targetDependencyCaches.createIfNotExists(self.db)
    try self.csourceFiles.createIfNotExists(self.db)
    try self.globalConfigurations.createIfNotExists(self.db)
    try self.dependencyFiles.createIfNotExists(self.db)
    try self.customFiles.createIfNotExists(self.db)
    try self.outputFiles.createIfNotExists(self.db)
    try self.cmakeProjects.createIfNotExists(self.db)
    try self.cmakeFiles.createIfNotExists(self.db)
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
  //let targetRetrievalLock: NSLock = NSLock()

  /// Get the id for the specified target.
  /// If the target hasn't been defined in the database, this function returns nil
  func getTarget(_ target: TargetRef) throws -> Int64? {
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
  //func getTarget(_ target: TargetRef) throws -> Int64? {
    //try self.targetRetrievalLock.withLock {
      //try self.__getTargetIfExists(target)
    //}
  //}

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

    guard let configId = self.configurationId else {
      throw CacheError.noConfigurationSelected
    }
    let targetId = try self.getTarget(target)!
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
      for row in try self.db.prepare(filesQuery) {
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

  /// Returns wether any of the dependency files have changed, or if new files have
  /// been added. A dependency file can be an artifact generated by the target's
  /// dependencies.
  ///
  /// Updates the cache to reflect the latest update date of these files.
  func dependencyFilesChanged(
    currentFiles: borrowing [URL],
    target: TargetRef,
    forBuildingArtifact artifactType: ArtifactType
  ) throws -> Bool {
    guard let configId = self.configurationId else {
      throw CacheError.noConfigurationSelected
    }
    let targetId = try self.getTarget(target)!

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

  func shouldRelinkArtifact(
    target: TargetRef,
    artifact: ArtifactType,
    artifactFile: URL
  ) throws -> Bool {
    guard let configId = self.configurationId else {
      throw CacheError.noConfigurationSelected
    }
    let targetId = try self.getTarget(target)!

    let outputFileRow = try self.db.pluck(self.outputFiles.table
      .select(self.outputFiles.filename.qualified, self.outputFiles.relink.qualified)
      //.join(.inner, self.files.table, on: self.files.id.qualified == self.outputFiles.fileId.qualified)
      .where(
           self.outputFiles.targetId.qualified == targetId
        && self.outputFiles.configId.qualified == configId
      )
    )
    let currentFilepath = artifactFile.absoluteURL.path
    if let outputFileRow = outputFileRow {
      let relink = outputFileRow[self.outputFiles.relink.qualified]
      if relink {
        try self.db.run(self.outputFiles.table
          .where(self.outputFiles.targetId.qualified == targetId && self.outputFiles.configId.qualified == configId)
          .update(self.outputFiles.relink.unqualified <- false))
      }
      let outputFilepath = outputFileRow[self.outputFiles.filename.qualified]
      if currentFilepath != outputFilepath {
        try self.db.run(self.outputFiles.table
          .where(self.outputFiles.targetId.qualified == targetId && self.outputFiles.configId.qualified == configId)
          .update(self.outputFiles.filename.unqualified <- currentFilepath))
        return true
      } else {
        return false || relink
      }
    } else {
      try self.db.run(self.outputFiles.table
        .insert([
          self.outputFiles.filename.unqualified <- currentFilepath,
          self.outputFiles.configId.unqualified <- configId,
          self.outputFiles.targetId.unqualified <- targetId,
          self.outputFiles.artifactType.unqualified <- artifact,
          self.outputFiles.relink.unqualified <- false
        ]))
      return true
    }
  }

  /// Returns true if file has changed
  @usableFromInline
  func fileChanged(
    _ file: URL,
    context: String
  ) throws -> Bool {
    guard let configId = self.configurationId else {
      throw CacheError.noConfigurationSelected
    }
    guard let fileRow = try db.pluck(self.files.table
      .join(.inner, self.customFiles.table, on: self.customFiles.fileId.qualified == self.files.id.qualified)
      .where(self.customFiles.context.qualified == context && self.customFiles.configId.qualified == configId)
    ) else {
      let attrs = try FileChecker.fileAttrs(file: file)
      let id = try self.db.run(self.files.table
        .insert([
          self.files.filename.unqualified <- file.absoluteURL.path,
          self.files.mtime.unqualified <- Int64(timespec_to_ms(attrs.st_mtimespec)),
          self.files.size.unqualified <- Int64(attrs.st_size),
          self.files.inodeNumber.unqualified <- UInt64(attrs.st_ino),
          self.files.fileMode.unqualified <- UInt64(attrs.st_mode),
          self.files.ownerUid.unqualified <- UInt64(attrs.st_uid),
          self.files.ownerGid.unqualified <- UInt64(attrs.st_gid),
        ]))
      try self.db.run(self.customFiles.table
        .insert([
          self.customFiles.fileId.unqualified <- id,
          self.customFiles.configId.unqualified <- configId,
          self.customFiles.context.unqualified <- context
        ]))
      return true
    }

    let file = FileChecker.fileFromRow(fileRow)
    let (changed, attrs) = try FileChecker.fileChanged(file: file)

    if changed {
      try self.files.update(id: file.id!, attrs, self.db)
    }

    return changed
  }

  /// removes a target from its target id in the database
  @discardableResult
  func removeTarget(targetId: Int64) throws -> Bool {
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

  /// Returns false if nothing had to be removed
  @discardableResult
  func removeTarget(target: TargetRef) throws -> Bool {
    guard let targetId = try self.getTarget(target) else {
      return false
    }
    return try self.removeTarget(targetId: targetId)
  }

  @available(*, deprecated, message: "Remove the cache file instead. This should be revisited in the future")
  func reset() throws {
    try self.db.run(self.files.table.delete())
    try self.db.run(self.csourceFiles.table.delete())
    try self.db.run(self.configurations.table.delete())
    try self.db.run(self.targets.table.delete())
  }
}
