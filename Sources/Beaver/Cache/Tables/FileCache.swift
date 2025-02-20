import Foundation
import timespec
@preconcurrency import SQLite

@CacheEntry(name: "File")
struct FileCache {
  let checkId: UUID

  @PrimaryKey(true)
  let filename: URL
  /// Modified time
  let mtime: Int64
  /// File size
  let size: Int64
  /// inode number
  let ino: UInt64
  /// file mode
  let mode: UInt64
  /// owner UID
  let uid: UInt64
  /// owner GID
  let gid: UInt64

  init(file: URL, fromAttrs attrs: stat) {
    self.filename = file
    self.checkId = UUID()
    self.mtime = Int64(timespec_to_ms(attrs.st_mtimespec))
    self.size = Int64(attrs.st_size)
    self.ino = UInt64(attrs.st_ino)
    self.mode = UInt64(attrs.st_mode)
    self.uid = UInt64(attrs.st_uid)
    self.gid = UInt64(attrs.st_gid)
  }

  init(file: URL) throws {
    self.filename = file
    self.checkId = UUID()
    let attrs = try FileChecker.fileAttrs(file: file)
    self.mtime = Int64(timespec_to_ms(attrs.st_mtimespec))
    self.size = Int64(attrs.st_size)
    self.ino = UInt64(attrs.st_ino)
    self.mode = UInt64(attrs.st_mode)
    self.uid = UInt64(attrs.st_uid)
    self.gid = UInt64(attrs.st_gid)
  }

  init(row: Row) throws {
    self.filename = row[Self.Columns.filename.qualified]
    self.checkId = row[Self.Columns.checkId.qualified]
    self.mtime = row[Self.Columns.mtime.qualified]
    self.size = row[Self.Columns.size.qualified]
    self.ino = row[Self.Columns.ino.qualified]
    self.mode = row[Self.Columns.mode.qualified]
    self.uid = row[Self.Columns.uid.qualified]
    self.gid = row[Self.Columns.gid.qualified]
  }

  static func getRow(_ file: URL, _ db: Connection) throws -> Row? {
    try db.pluck(Self.table.where(Self.Columns.filename.qualified == file))
  }

  static func get(_ file: URL, _ db: Connection) throws -> FileCache? {
    if let row = try Self.getRow(file, db) {
      FileCache(row)
    } else {
      nil
    }
  }

  static func update(_ newFile: FileCache, _ db: Connection) throws {
    try db.run(Self.table
      .where(Self.Columns.filename.unqualified == newFile.filename)
      .update(newFile.setter))
  }

  static func exists(_ file: URL, _ db: Connection) throws -> Bool {
    try db.scalar(Self.table
      .where(Self.Columns.filename.qualified == file)
      .exists)
  }

  static func getOrInsert(_ file: URL, _ db: Connection) throws -> FileCache {
    if let c = try self.get(file, db) {
      return c
    } else {
      let fileCache = try FileCache(file: file)
      try fileCache.insert(db)
      return fileCache
    }
  }
}
