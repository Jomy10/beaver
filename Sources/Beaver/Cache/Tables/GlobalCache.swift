import Foundation
@preconcurrency import SQLite

@CacheEntry
struct GlobalCache {
  let id: UUID
  let buildId: Int
  /// Environment variables (MD5 hash)
  let env: Data

  static func changed(buildId: Int, env: Data, _ db: Connection, reason: UnsafeMutablePointer<String?>? = nil) throws -> Bool {
    let changed: Bool
    if let row = try db.pluck(Self.table) {
      if row[Self.Columns.buildId.unqualified] != buildId {
        reason?.pointee = "Previous artifacts were built with a different version of Beaver"
        changed = true
      } else if row[Self.Columns.env.unqualified] != env {
        reason?.pointee = "Environment variables changed since last invocation"
        changed = true
      } else {
        changed = false
      }
    } else {
      changed = true
    }

    if changed {
      try db.run(Self.table
        .update([
          Self.Columns.id.unqualified <- UUID(),
          Self.Columns.buildId.unqualified <- buildId,
          Self.Columns.env.unqualified <- env,
        ]))
    }

    return changed
  }

  static func changed(buildId: Int, env: Data, _ db: Connection, reason: inout String?) throws -> Bool {
    try withUnsafeMutablePointer(to: &reason) { ptr in
      try self.changed(buildId: buildId, env: env, db, reason: ptr)
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
