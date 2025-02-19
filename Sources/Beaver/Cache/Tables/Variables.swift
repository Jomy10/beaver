import Foundation
@preconcurrency import SQLite

@CacheEntry(name: "Variable")
struct CacheVariable {
  let name: String
  let val: CacheVarVal

  static func getValue(name: String, _ db: Connection) throws -> CacheVarVal? {
    try db.pluck(Self.table
      .select(Self.Columns.val.unqualified)
      .where(Self.Columns.name.unqualified == name)
    )?[Self.Columns.val.unqualified]
  }

  static func updateOrInsert(_ v: CacheVariable, _ db: Connection) throws {
    if try db.scalar(Self.table.where(Self.Columns.name.unqualified == v.name).exists) {
      try db.run(Self.table
        .where(Self.Columns.name.unqualified == v.name)
        .update(Self.Columns.val.unqualified <- v.val))
    } else {
      try v.insert(db)
    }
  }
}
