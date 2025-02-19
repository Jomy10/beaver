import Foundation
@preconcurrency import SQLite

@CacheEntry(name: "Configuration")
struct ConfigurationCache {
  @PrimaryKey(SQLite.PrimaryKey.autoincrement)
  let id: Int64
  let mode: OptimizationMode
}
