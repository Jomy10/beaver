import Foundation
@preconcurrency import SQLite

@CacheEntry(name: "Configuration")
struct ConfigurationCache {
  @PrimaryKey(SQLite.PrimaryKey.autoincrement)
  let id: Int64
  let mode: OptimizationMode

  static func getRow(mode: OptimizationMode, _ db: Connection) throws -> Row? {
    return try db.pluck(Self.table
      .where(Self.Columns.mode.unqualified == mode))
  }

  static func get(mode: OptimizationMode, _ db: Connection) throws -> Self? {
    if let row = try self.getRow(mode: mode, db) {
      return Self(id: row[Self.Columns.id.unqualified], mode: row[Self.Columns.mode.unqualified])
    } else {
      return nil
    }
  }
}
