import Foundation
import SQLite
import Utils
import timespec

/// Checks if a file has changed
///
/// This approach is similar to `redo` as outlined in [this article](https://apenwarr.ca/log/20181113)
/// (see redo: mtime dependencies done right)
struct FileChecker {
  //typealias FileDef = (filename: String, mtime: Int64?, size: Int64?, ino: UInt64?, mode: UInt64?, uid: UInt64?, gid: UInt64?)

//  static func fileFromFileEntry(_ file: File) -> FileDef {
//    (
//      filename: file.filename,
//      mtime: file.mtime,
//      size: file.size,
//      ino: file.ino,
//      mode: file.mode,
//      uid: file.uid,
//      gid: file.gid
//    )
//  }
  //static func fileFromRow(_ row: Row) -> File {
  //  (
  //    filename: row[SQLite.Expression<String>("filename")],
  //    id: row[SQLite.Expression<Int64?>("id")],
  //    mtime: row[SQLite.Expression<Int64?>("mtime")],
  //    size: row[SQLite.Expression<Int64?>("size")],
  //    ino: row[SQLite.Expression<UInt64?>("ino")],
  //    mode: row[SQLite.Expression<UInt64?>("mode")],
  //    uid: row[SQLite.Expression<UInt64?>("uid")],
  //    gid: row[SQLite.Expression<UInt64?>("gid")]
  //  )
  //}

  static func fileAttrs(file: URL) throws -> stat {
    //let filename = file.absoluteURL.path
    let attrs = try FileManager.default.stat(at: file)
    //var attrs = stat()
    //try filename.withCString({ str in
    //  if stat(str, &attrs) == -1 {
    //    if errno == EOVERFLOW {
    //      MessageHandler.print("An error occured in `stat` that might be solved by using stat64, please open an issue or fix this by opening a pull request for Beaver at https://github.com/Jomy10/Beaver")
    //    }
    //    throw StatError(filename: filename, code: errno)
    //  }
    //})
    return attrs
  }

  // TODO
  /// Returns whether the file has changed and the new `stat` of the file.
  /// Also returns true if the file has not been cached before (e.g. it is a new file)
  static func fileChanged(_ file: FileCache) throws -> (Bool, stat) {
    //let filename = file.filename.path

    let attrs = try FileManager.default.stat(at: file.filename)
    //var attrs = stat()
    //try filename.withCString({ str in
    //  if stat(str, &attrs) == -1 {
    //    if errno == EOVERFLOW {
    //      MessageHandler.print("An error occured in `stat` that might be solved by using stat64, please open an issue or fix this by opening a pull request for Beaver at https://github.com/Jomy10/Beaver")
    //    }
    //    throw StatError(filename: filename, code: errno)
    //  }
    //})

    let newMtime = Int64(timespec_to_ms(attrs.st_mtimespec))
    if file.mtime != newMtime { return (true, attrs) }

    if file.size != attrs.st_size { return (true, attrs) }

    if file.ino != attrs.st_ino { return (true, attrs) }

    if file.mode != attrs.st_mode { return (true, attrs) }

    if file.uid != attrs.st_uid { return (true, attrs) }

    if file.gid != attrs.st_gid { return (true, attrs) }

    return (false, attrs) // All checks passed; file hasn't changed
  }
}
