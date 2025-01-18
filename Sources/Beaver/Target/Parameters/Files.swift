import Foundation
import Glob

// TODO: rewrite --> if !contains *; then expand directory if directory else expand glob
public struct Files: Sendable {
  private var include: Storage
  private var exclude: Storage
  private var skipHiddenFiles: Bool

  public typealias Storage = [String]

  public init(
    include: Storage,
    exclude: Storage = [],
    skipHiddenFiles: Bool = true
  ) {
    self.include = include
    self.exclude = exclude
    self.skipHiddenFiles = skipHiddenFiles
  }

  typealias ResultType = AsyncThrowingFilterSequence<AsyncThrowingStream<URL, any Error>> //any AsyncSequence<URL, any Error>

  func files(baseDir: URL) throws -> ResultType? {
    if self.include.count == 0 { return nil }

    return try self.searchGlobs(include: self.include, exclude: self.exclude, baseDir: baseDir, skipHiddenFiles: self.skipHiddenFiles)
      .filter { url in
        try !url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory!
      }
  }

  func searchGlobs(include: [String], exclude: [String], baseDir: URL, skipHiddenFiles: Bool = true) throws -> AsyncThrowingStream<URL, any Error> {
    let include = try include.map { pat in try Self.patToGlob(pat, baseDir: baseDir) }
    return Glob.search(
      directory: baseDir,
      include: include,
      exclude: try exclude.map { pat in try Self.patToGlob(pat, baseDir: baseDir) },
      includingPropertiesForKeys: [.isDirectoryKey],
      skipHiddenFiles: skipHiddenFiles
    )
  }

  private static func patToGlob(_ pat: String, baseDir: URL) throws -> Glob.Pattern {
    if pat.contains("*") {
      try Glob.Pattern(pat)
    } else {
      if FileManager.default.isDirectory(URL(filePath: pat, relativeTo: baseDir)) {
        try Glob.Pattern(pat + "/**/*")
      } else {
        try Glob.Pattern(pat)
      }
    }
  }


  //func files(baseURL: URL) throws -> ResultType {
  //  switch (self.include) {
  //    case .glob(let globPat):
  //      return try self.filesWithIncludeGlobPattern([try Glob.Pattern(globPat)], baseURL: baseURL)
  //    case .globArray(let globPats):
  //      return try self.filesWithIncludeGlobPattern(try globPats.map { globPat in try Glob.Pattern(globPat) }, baseURL: baseURL)
  //    case .url(let url):
  //      return self.filesFromURLS(self.expandURL(url))
  //    case .urlArray(let urls):
  //      return self.filesFromURLS(urls.flatMap { self.expandURL($0) })
  //  }
  //}

  //@inline(__always)
  //private func filesWithIncludeGlobPattern(_ includeGlobPatterns: [Glob.Pattern], baseURL: URL) throws -> ResultType {
  //  switch (self.exclude) {
  //    case .glob(let globPat):
  //      return self.filesWithIncludeAndExcludeGlobPattern(includeGlobPatterns, [try Glob.Pattern(globPat)], baseURL: baseURL)
  //    case .globArray(let globPats):
  //      return self.filesWithIncludeAndExcludeGlobPattern(includeGlobPatterns, try globPats.map { try Glob.Pattern($0) }, baseURL: baseURL)
  //    case .url(let url):
  //      return self.filesWithIncludeAndExcludeGlobPattern(includeGlobPatterns, [], baseURL: baseURL)
  //        .filter { $0 != url }
  //    case .urlArray(let urls):
  //      return self.filesWithIncludeAndExcludeGlobPattern(includeGlobPatterns, [], baseURL: baseURL)
  //        .filter { !urls.contains($0) }
  //    case .none:
  //      return self.filesWithIncludeAndExcludeGlobPattern(includeGlobPatterns, [], baseURL: baseURL)
  //  }
  //}

  //@inline(__always)
  //private func filesWithIncludeAndExcludeGlobPattern(_ includeGlobPatterns: [Glob.Pattern], _ excludeGlobPatterns: [Glob.Pattern], baseURL: URL) -> AsyncThrowingStream<URL, any Error> {
  //  return Glob.search(
  //    directory: baseURL,
  //    include: includeGlobPatterns,
  //    exclude: excludeGlobPatterns,
  //    skipHiddenFiles: !self.includeHiddenFiles
  //  )
  //}

  //@inline(__always)
  //private func expandURL(_ url: URL) -> [URL] {
  //  MessageHandler.print("\(url) isDirectory: \(url.isDirectory)")
  //  if url.isDirectory {
  //    return url.recursiveContentsOfDirectory(skipHiddenFiles: !self.includeHiddenFiles)
  //  } else {
  //    return [url]
  //  }
  //}

  //@inline(__always)
  //private func filesFromURLS(_ urls: [URL]) -> ResultType {
  //  return AsyncThrowingStream { continuation in
  //    let _urls: [URL]
  //    if let exclude = self.exclude {
  //      switch (exclude) {
  //        case .glob(let globPatString):
  //          let globPat: Glob.Pattern
  //          do {
  //            globPat = try Glob.Pattern(globPatString)
  //          } catch let error {
  //            continuation.finish(throwing: error)
  //            return
  //          }
  //          _urls = urls.filter { url in !globPat.match(url.relativePath) }
  //        case .globArray(let globPatStrings):
  //          guard let globPats = try? globPatStrings.map({ pat in
  //            do {
  //              return try Glob.Pattern(pat)
  //            } catch let error {
  //              continuation.finish(throwing: error)
  //              throw error
  //            }
  //          }) else {
  //            return
  //          }
  //          _urls = urls.filter { url in globPats.first(where: { $0.match(url.relativePath) }) == nil }
  //        case .url(let excludeURL):
  //          _urls = urls.filter { url in url != excludeURL }
  //        case .urlArray(let excludeURLs):
  //          _urls = urls.filter { url in !excludeURLs.contains(url) }
  //      }
  //    } else {
  //      _urls = urls
  //    }

  //    for url in _urls {
  //      continuation.yield(url)
  //    }
  //    continuation.finish()
  //  }
  //}
}

extension Files: ExpressibleByStringLiteral {
  public init(stringLiteral: StringLiteralType) {
    self.include = [stringLiteral]
    self.exclude = []
    self.skipHiddenFiles = false
  }
}

extension Files: ExpressibleByArrayLiteral {
  public typealias ArrayLiteralElement = String

  public init(arrayLiteral: ArrayLiteralElement...) {
    self.include = arrayLiteral
    self.exclude = []
    self.skipHiddenFiles = false
  }
}

//extension Files.Storage: ExpressibleByStringLiteral {
//  public init(stringLiteral: StringLiteralType) {
//    self = [String(stringLiteral)]
//  }
//}

//extension Files.Storage: ExpressibleByArrayLiteral {
//  public typealias ArrayLiteralElement = String

//  public init(arrayLiteral: ArrayLiteralElement...) {
//    self = arrayLiteral
//  }
//}
