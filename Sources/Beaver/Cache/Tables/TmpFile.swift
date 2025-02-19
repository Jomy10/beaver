import Foundation
@preconcurrency import SQLite

@CacheEntry
struct TmpFile {
  let file: URL
}
