import Foundation
@preconcurrency import SQLite

@CacheEntry
struct CustomFile {
  let file: URL
  let context: String
  let checkId: UUID
}
