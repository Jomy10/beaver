import Foundation
import Platform

extension URL {
  public func recursiveContentsOfDirectory(skipHiddenFiles: Bool = false) -> [URL] {
    guard let contents = try? FileManager.default.contentsOfDirectory(at: self, includingPropertiesForKeys: nil, options: skipHiddenFiles ? .skipsHiddenFiles : []) else {
      return []
    }
    return contents.flatMap { url in
      if FileManager.default.isDirectory(url) {
        return url.recursiveContentsOfDirectory(skipHiddenFiles: skipHiddenFiles)
      } else {
        return [url]
      }
    }
  }

  public func unsafeRelativePath(from base: URL) -> String? {
    guard self.isFileURL && base.isFileURL else {
      return nil
    }

    let destComponents: [String] = self.standardized.pathComponents
    let baseComponentCount: Int = base.standardized.pathComponents.count

    return destComponents[baseComponentCount...].joined(separator: PATH_SEPARATOR)
  }

  public var dirURL: URL? {
    guard self.isFileURL else { return nil }

    let components = self.pathComponents
    return URL(filePath: components[..<(components.count-1)].joined(separator: PATH_SEPARATOR))
  }
}
