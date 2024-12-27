import Foundation
import Glob

public struct Headers: Sendable {
  private var `public`: Files?
  private var `private`: Files?

  public func publicHeaders(baseDir: URL) async throws -> [URL]? {
    return try await self.public?.files(baseURL: baseDir)
      .reduce(into: [URL]()) { $0.append($1) }
      .map { file in
        if file.isDirectory {
          return file
        } else {
          return file.dirURL!
        }
      }.unique
  }

  public func privateHeaders(baseDir: URL) async throws -> [URL]? {
    return try await self.private?.files(baseURL: baseDir)
      .reduce(into: [URL]()) { $0.append($1) }
      .map { file in
        if file.isDirectory {
          return file
        } else {
          return file.dirURL!
        }
      }.unique
  }

  public init() {
    self.public = nil
    self.private = nil
  }

  public init(
    `public`: Files? = nil,
    `private`: Files? = nil
  ) {
    self.public = `public`
    self.private = `private`
  }

  public init(
    `public`: [URL]? = nil,
    `private`: [URL]? = nil
  ) {
    if let publicHeaders = `public` {
      self.public = Files(include: .urlArray(publicHeaders))
    } else {
      self.public = nil
    }
    if let privateHeaders = `private` {
      self.private = Files(include: .urlArray(privateHeaders))
    } else {
      self.private = nil
    }
  }
}

public struct Files: Sendable {
  private var include: Storage
  private var exclude: Storage?
  private var includeHiddenFiles: Bool

  public init(
    include: Storage,
    exclude: Storage? = nil,
    includeHiddenFiles: Bool = false
  ) {
    self.include = include
    self.exclude = exclude
    self.includeHiddenFiles = includeHiddenFiles
  }

  public enum Storage: Sendable {
    case glob(String)
    case globArray([String])
    case url(URL)
    case urlArray([URL])

    public static func contentsOf(directory: URL) -> Self {
      return .url(directory)
    }
  }

  typealias ResultType = any AsyncSequence<URL, any Error>

  // TODO: support for older macOS versions

  func files(baseURL: URL) throws -> ResultType {
    switch (self.include) {
      case .glob(let globPat):
        return try self.filesWithIncludeGlobPattern([try Glob.Pattern(globPat)], baseURL: baseURL)
      case .globArray(let globPats):
        return try self.filesWithIncludeGlobPattern(try globPats.map { globPat in try Glob.Pattern(globPat) }, baseURL: baseURL)
      case .url(let url):
        return self.filesFromURLS(self.expandURL(url))
      case .urlArray(let urls):
        return self.filesFromURLS(urls)
    }
  }

  @inline(__always)
  private func filesWithIncludeGlobPattern(_ includeGlobPatterns: [Glob.Pattern], baseURL: URL) throws -> ResultType {
    switch (self.exclude) {
      case .glob(let globPat):
        return self.filesWithIncludeAndExcludeGlobPattern(includeGlobPatterns, [try Glob.Pattern(globPat)], baseURL: baseURL)
      case .globArray(let globPats):
        return self.filesWithIncludeAndExcludeGlobPattern(includeGlobPatterns, try globPats.map { try Glob.Pattern($0) }, baseURL: baseURL)
      case .url(let url):
        return self.filesWithIncludeAndExcludeGlobPattern(includeGlobPatterns, [], baseURL: baseURL)
          .filter { $0 != url }
      case .urlArray(let urls):
        return self.filesWithIncludeAndExcludeGlobPattern(includeGlobPatterns, [], baseURL: baseURL)
          .filter { !urls.contains($0) }
      case .none:
        return self.filesWithIncludeAndExcludeGlobPattern(includeGlobPatterns, [], baseURL: baseURL)
    }
  }

  @inline(__always)
  private func filesWithIncludeAndExcludeGlobPattern(_ includeGlobPatterns: [Glob.Pattern], _ excludeGlobPatterns: [Glob.Pattern], baseURL: URL) -> AsyncThrowingStream<URL, any Error> {
    return Glob.search(
      directory: baseURL,
      include: includeGlobPatterns,
      exclude: excludeGlobPatterns,
      skipHiddenFiles: !self.includeHiddenFiles
    )
  }

  @inline(__always)
  private func expandURL(_ url: URL) -> [URL] {
    if url.isDirectory {
      return url.recursiveContentsOfDirectory(skipHiddenFiles: !self.includeHiddenFiles)
    } else {
      return [url]
    }
  }

  @inline(__always)
  private func filesFromURLS(_ urls: [URL]) -> ResultType {
    return AsyncThrowingStream { continuation in
      let _urls: [URL]
      if let exclude = self.exclude {
        switch (exclude) {
          case .glob(let globPatString):
            let globPat: Glob.Pattern
            do {
              globPat = try Glob.Pattern(globPatString)
            } catch let error {
              continuation.finish(throwing: error)
              return
            }
            _urls = urls.filter { url in !globPat.match(url.relativePath) }
          case .globArray(let globPatStrings):
            guard let globPats = try? globPatStrings.map({ pat in
              do {
                return try Glob.Pattern(pat)
              } catch let error {
                continuation.finish(throwing: error)
                throw error
              }
            }) else {
              return
            }
            _urls = urls.filter { url in globPats.first(where: { $0.match(url.relativePath) }) == nil }
          case .url(let excludeURL):
            _urls = urls.filter { url in url != excludeURL }
          case .urlArray(let excludeURLs):
            _urls = urls.filter { url in !excludeURLs.contains(url) }
        }
      } else {
        _urls = urls
      }

      for url in _urls {
        continuation.yield(url)
      }
      continuation.finish()
    }
  }
}

extension Files: ExpressibleByStringLiteral {
  public init(stringLiteral: StringLiteralType) {
    self.include = Storage(stringLiteral: stringLiteral)
    self.exclude = nil
    self.includeHiddenFiles = false
  }
}

extension Files: ExpressibleByArrayLiteral {
  public typealias ArrayLiteralElement = String

  public init(arrayLiteral: ArrayLiteralElement...) {
    self.include = .globArray(arrayLiteral)
    self.exclude = nil
    self.includeHiddenFiles = false
  }
}

extension Files.Storage: ExpressibleByStringLiteral {
  public init(stringLiteral: StringLiteralType) {
    self = .glob(String(stringLiteral))
  }
}

extension Files.Storage: ExpressibleByArrayLiteral {
  public typealias ArrayLiteralElement = String

  public init(arrayLiteral: ArrayLiteralElement...) {
    self = .globArray(arrayLiteral)
  }
}

extension Headers: ExpressibleByStringLiteral {
  public init(stringLiteral: StringLiteralType) {
    self.public = Files(stringLiteral: stringLiteral)
    self.private = nil
  }
}

extension Headers: ExpressibleByArrayLiteral {
  public typealias ArrayLiteralElement = String

  public init(arrayLiteral: ArrayLiteralElement...) {
    self.public = Files(include: .globArray(arrayLiteral), exclude: nil, includeHiddenFiles: false)
    self.private = nil
  }
}
