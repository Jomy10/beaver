import Foundation
import Platform

extension URL {
  @available(*, deprecated, message: "Use FileManager.default.isDirectory(_:) from Utils")
  var isDirectory: Bool {
    var oisDir: ObjCBool = false
    if !FileManager.default.fileExists(atPath: self.path, isDirectory: &oisDir) { return false }
    return oisDir.boolValue
  }

  @available(*, deprecated, message: "Use FileManager.default.exists(at:) from Utils")
  var exists: Bool {
    return FileManager.default.fileExists(atPath: self.path)
  }

  func recursiveContentsOfDirectory(skipHiddenFiles: Bool = false) -> [URL] {
    guard let contents = try? FileManager.default.contentsOfDirectory(at: self, includingPropertiesForKeys: nil, options: skipHiddenFiles ? .skipsHiddenFiles : []) else {
      return []
    }
    return contents.flatMap { url in
      if url.isDirectory {
        return url.recursiveContentsOfDirectory(skipHiddenFiles: skipHiddenFiles)
      } else {
        return [url]
      }
    }
  }

  func unsafeRelativePath(from base: URL) -> String? {
    guard self.isFileURL && base.isFileURL else {
      return nil
    }

    let destComponents: [String] = self.standardized.pathComponents
    let baseComponentCount: Int = base.standardized.pathComponents.count

    return destComponents[baseComponentCount...].joined(separator: PATH_SEPARATOR)
  }

  var dirURL: URL? {
    guard self.isFileURL else { return nil }

    let components = self.pathComponents
    return URL(filePath: components[..<(components.count-1)].joined(separator: PATH_SEPARATOR))
  }
}
