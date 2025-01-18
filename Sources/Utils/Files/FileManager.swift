import Foundation

extension FileManager {
  @inlinable
  public func exists(at url: URL) -> Bool {
    self.fileExists(atPath: url.path)
  }

  @inlinable
  public func isDirectory(_ url: URL) -> Bool {
    var isDir: ObjCBool = false
    if !self.fileExists(atPath: url.path, isDirectory: &isDir) { return false }
    return isDir.boolValue
  }

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

  @inlinable
  public func createDirectoryIfNotExists(at url: URL, withIntermediateDirectories: Bool = true) throws {
    if !self.exists(at: url) {
      try self.createDirectory(at: url, withIntermediateDirectories: withIntermediateDirectories)
    }
  }
}
