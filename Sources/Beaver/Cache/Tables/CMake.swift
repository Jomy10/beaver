import Foundation
@preconcurrency import SQLite

@CacheEntry(name: "CMakeProject")
struct CMakeProjectCache {
  @PrimaryKey(.autoincrement)
  let id: Int64
  let path: URL

  init(row: Row) {
    self.id = row[Self.Columns.id.unqualified]
    self.path = row[Self.Columns.path.unqualified]
  }

  init(id: Int64, path: URL) {
    self.id = id
    self.path = path
  }

  static func insertNew(_ path: URL, _ db: Connection) throws -> Int64 {
    try db.run(Self.table.insert([
      Self.Columns.path.unqualified <- path
    ]))
  }

  static func getRow(path: URL, _ db: Connection) throws -> Row? {
    try db.pluck(Self.table
      .where(Self.Columns.path.unqualified == path))
  }

  static func get(path: URL, _ db: Connection) throws -> Self? {
    if let row = try Self.getRow(path: path, db) {
      return CMakeProjectCache(row: row)
    } else {
      return nil
    }
  }

  static func getRow(id: Int64, _ db: Connection) throws -> Row? {
    try db.pluck(Self.table
      .where(Self.Columns.id.unqualified == id))
  }

  static func get(id: Int64, _ db: Connection) throws -> Self? {
    if let row = try self.getRow(id: id, db) {
      return CMakeProjectCache(row: row)
    } else {
      return nil
    }
  }
}

@CacheEntry
struct CMakeFile {
  let cmakeProjectId: Int64
  let file: URL
}
