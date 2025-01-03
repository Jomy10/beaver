import Foundation

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
