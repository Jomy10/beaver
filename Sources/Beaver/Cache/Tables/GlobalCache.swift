import Foundation
@preconcurrency import SQLite

@CacheEntry
struct GlobalCache {
  let id: UUID
  let buildId: Int
  /// Environment variables (MD5 hash)
  let env: Data

  static func changed(buildId: Int, env: Data, _ db: Connection) throws -> Bool {
    if let row = try db.pluck(Self.table) {
      if row[Self.Columns.buildId.unqualified] != buildId || row[Self.Columns.env.unqualified] != env {
        try db.run(Self.table
          .update([
            Self.Columns.id.unqualified <- UUID(),
            Self.Columns.buildId.unqualified <- buildId,
            Self.Columns.env.unqualified <- env,
          ]))
        return true
      } else {
        return false
      }
    } else {
      return true
    }
  }

  /// Returns true if cache has changed
  static func insert(buildId: Int, env: Data, _ db: Connection) throws {
    try db.run(Self.table
      .insert([
        Self.Columns.id.unqualified <- UUID(),
        Self.Columns.buildId.unqualified <- buildId,
        Self.Columns.env.unqualified <- env,
      ]))
  }
}
