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
  public func createDirectoryIfNotExists(at url: URL, withIntermediateDirectories: Bool = true) throws {
    if !self.exists(at: url) {
      try self.createDirectory(at: url, withIntermediateDirectories: withIntermediateDirectories)
    }
  }

  @inlinable
  public func createFile(at url: URL, contents: Data? = nil) throws(FileCreationError) {
    if !self.createFile(atPath: url.path, contents: contents) {
      throw FileCreationError("Creation of file \(url.path) failed")
    }
  }

  @inlinable
  public func createFile(at url: URL, contents: String? = nil, encoding: Swift.String.Encoding = .utf8) throws(FileCreationError) {
    guard let data = contents?.data(using: encoding) else {
      throw FileCreationError("Couldn't encode '\(contents ?? "")' as \(encoding)")
    }

    try self.createFile(at: url, contents: data)
  }
}

public struct FileCreationError: Error {
  let message: String

  public init(_ message: String) {
    self.message = message
  }
}
