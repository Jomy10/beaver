import Foundation
import SQLite
import Utils
import timespec

/// Checks if a file has changed
///
/// This approach is similar to `redo` as outlined in [this article](https://apenwarr.ca/log/20181113)
/// (see redo: mtime dependencies done right)
struct FileChecker {
  typealias File = (filename: String, id: Int64?, mtime: Int64?, size: Int64?, ino: UInt64?, mode: UInt64?, uid: UInt64?, gid: UInt64?)

  static func fileFromRow(_ row: Row) -> File {
    (
      filename: row[SQLite.Expression<String>("filename")],
      id: row[SQLite.Expression<Int64?>("id")],
      mtime: row[SQLite.Expression<Int64?>("mtime")],
      size: row[SQLite.Expression<Int64?>("size")],
      ino: row[SQLite.Expression<UInt64?>("ino")],
      mode: row[SQLite.Expression<UInt64?>("mode")],
      uid: row[SQLite.Expression<UInt64?>("uid")],
      gid: row[SQLite.Expression<UInt64?>("gid")]
    )
  }

  static func fileAttrs(file: URL) throws -> stat {
    let filename = file.absoluteURL.path
    var attrs = stat()
    try filename.withCString({ str in
      if stat(str, &attrs) == -1 {
        if errno == EOVERFLOW {
          MessageHandler.print("An error occured in `stat` that might be solved by using stat64, please open an issue or fix this by opening a pull request for Beaver at https://github.com/Jomy10/Beaver")
        }
        throw StatError(filename: filename, code: errno)
      }
    })
    return attrs
  }

  /// Returns wether the file has changed and the new `stat` of the file.
  /// Also returns true if the file has not been cached before (e.g. it is a new file)
  static func fileChanged(file: Self.File) throws -> (Bool, stat) {
    let filename = file.filename

    var attrs = stat()
    try filename.withCString({ str in
      if stat(str, &attrs) == -1 {
        if errno == EOVERFLOW {
          MessageHandler.print("An error occured in `stat` that might be solved by using stat64, please open an issue or fix this by opening a pull request for Beaver at https://github.com/Jomy10/Beaver")
        }
        throw StatError(filename: filename, code: errno)
      }
    })

    // File hasn't been cached yet
    if file.id == nil {
      return (true, attrs)
    }

    if let mtime = file.mtime {
      let newMtime = Int64(timespec_to_ms(attrs.st_mtimespec))
      if mtime != newMtime { return (true, attrs) }
    } else {
      return (true, attrs)
    }

    if let size = file.size {
      if size != attrs.st_size { return (true, attrs) }
    } else {
      return (true, attrs)
    }

    if let ino = file.ino {
      if ino != attrs.st_ino { return (true, attrs) }
    } else {
      return (true, attrs)
    }

    if let mode = file.mode {
      if mode != attrs.st_mode { return (true, attrs) }
    } else {
      return (true, attrs)
    }

    if let uid = file.uid {
      if uid != attrs.st_uid { return (true, attrs) }
    } else {
      return (true, attrs)
    }

    if let gid = file.gid {
      if gid != attrs.st_gid { return (true, attrs) }
    } else {
      return (true, attrs)
    }

    return (false, attrs) // All checks passed; file hasn't changed
  }
}

// Stat docs:
// - https://www.mkssoftware.com/docs/man5/struct_stat.5.asp
// - https://learn.microsoft.com/en-us/cpp/c-runtime-library/reference/stat-functions?view=msvc-170
struct StatError: Error, CustomStringConvertible {
  let filename: String
  let code: Int32

  var description: String {
    let errMsg = switch (self.code) {
      case EACCES: "Search permission is denied for a component of the path prefix."
      case EIO: "An error occurred while reading from the file system."
      case ELOOP: "A loop exists in symbolic links encountered during resolution of the path argument."
      case ENAMETOOLONG: "The length of the pat argument exceeds {PATH_MAX} or a pathname component is longer than {NAME_MAX}."
      case ENOENT: "A component of path does not name an existing file or path is an empty string."
      case ENOTDIR: "A component of the path prefix is not a directory."
      case EOVERFLOW: "The file size in bytes or the number of blocks allocated to the file or the file serial number cannot be represented correctly in the structure pointed to by buf."
      default: String(cString: strerror(self.code)!)
    }
    return "Error executing `stat` for file '\(self.filename)': \(errMsg)"
  }
}
