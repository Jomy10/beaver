import Foundation

#if canImport(Darwin)
import Darwin
@usableFromInline
let _statFn = stat
@usableFromInline
typealias _statStruct = Darwin.stat
@usableFromInline
let _chmodFn = chmod
#elseif canImport(Glibc)
import Glibc
@usableFromInline
let _statFn = stat
@usableFromInline
typealias _statStruct = Glibc.stat
@usableFromInline
let _chmodFn = chmod
#elseif canImport(Musl)
import Musl
@usableFromInline
let _statFn = stat
@usableFromInline
typealias _statStruct = Musl.stat
@usableFromInline
let _chmodFn = chmod
#elseif os(Windows)
import ucrt
@usableFromInline
let _statFn = _stat
@usableFromInline
typealias _statStruct = _stat
@usableFromInline
let _chmodFn = _chmod
#else
#warning("Need implementation for current platform to perform file permission changes")
#endif

extension FileManager {
  @inlinable
  public func isReadable(at url: URL) -> Bool {
    self.isReadableFile(atPath: url.path)
  }

  @inlinable
  public func isWritable(at url: URL) -> Bool {
    self.isWritableFile(atPath: url.path)
  }

  @inlinable
  public func isExecutable(at url: URL) -> Bool {
    self.isExecutableFile(atPath: url.path)
  }

  /// Write permissions for everyone
  @inlinable
  public func setWritable(at url: URL, _ target: ModeTarget = [.owner, .group, .others]) throws {
    let stat = try self.stat(at: url)
    var mode = stat.st_mode
    if target.contains(.group) {
      mode |= S_IWGRP
    }
    if target.contains(.owner) {
      mode |= S_IWUSR
    }
    if target.contains(.others) {
      mode |= S_IWOTH
    }
    try self.chmod(at: url, mode);
  }

  @inlinable
  public func chmod(at file: URL, _ mode: mode_t) throws {
    try self.chmod(file.path(percentEncoded: false), mode)
  }

  @inlinable
  public func chmod(_ filename: String, _ mode: mode_t) throws {
    if _chmodFn(filename, mode) == -1 {
      throw ChmodError(filename: filename, code: errno)
    }
  }

  @inlinable
  public func stat(at file: URL) throws -> stat {
    try self.stat(file.path(percentEncoded: false))
  }

  @inlinable
  public func stat(_ filename: String) throws -> stat {
    var attrs = _statStruct()
    try filename.withCString { str in
      if _statFn(str, &attrs) == -1 {
        throw StatError(filename: filename, code: errno)
      }
    }
    return attrs
  }
}

public struct ModeTarget: OptionSet, Sendable {
  public let rawValue: Int

  public init(rawValue: Int) {
    self.rawValue = rawValue
  }

  public static let owner = ModeTarget(rawValue: 1 << 0)
  public static let group = ModeTarget(rawValue: 1 << 1)
  public static let others = ModeTarget(rawValue: 1 << 2)
}

// Stat docs:
// - https://www.mkssoftware.com/docs/man5/struct_stat.5.asp
// - https://learn.microsoft.com/en-us/cpp/c-runtime-library/reference/stat-functions?view=msvc-170
public struct StatError: Error, CustomStringConvertible {
  let filename: String
  let code: Int32

  @usableFromInline
  init(filename: String, code: Int32) {
    self.filename = filename
    self.code = code
  }

  public var description: String {
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

public struct ChmodError: Error, CustomStringConvertible {
  let filename: String
  let code: Int32

  @usableFromInline
  init(filename: String, code: Int32) {
    self.filename = filename
    self.code = code
  }

  public var description: String {
    let errMsg = switch (self.code) {
      case EACCES: "Search permission is denied on a component of the path prefix.  (See also path_resolution(7).)"
      case EFAULT: "pathname points outside your accessible address space."
      case EIO: "An I/O error occurred."
      case ELOOP: "Too many symbolic links were encountered in resolving pathname."
      case ENAMETOOLONG: "pathname is too long."
      case ENOENT: "The file does not exist."
      case ENOMEM: "Insufficient kernel memory was available."
      case ENOTDIR: "A component of the path prefix is not a directory."
      case EPERM:
        #if os(Linux)
          "The effective UID does not match the owner of the file, and the process is not privileged. It does not have the CAP_FOWNER capability"
        #else
          "The effective UID does not match the owner of the file, and the process is not privileged."
        #endif
      case EPERM: "The file is marked immutable or append-only."
      case EROFS: "The named file resides on a read-only filesystem."
      default: String(cString: strerror(self.code))
    }
    return "Error executing `chmod` for file '\(self.filename)': \(errMsg)"
  }
}
