import Foundation

public struct Headers: Sendable {
  private var `public`: [String]
  private var `private`: [String]

  public func publicHeaders(baseDir: URL) -> [URL] {
    self.public.map { baseDir.appending(path: $0) }
    //return try await self.public?.files(baseDir: baseDir)
    //  .reduce(into: [URL]()) { $0.append($1) }
    //  .map { file in
    //    if file.isDirectory {
    //      return file
    //    } else {
    //      return file.dirURL!
    //    }
    //  }.unique
  }

  public func privateHeaders(baseDir: URL) -> [URL] {
    self.private.map { baseDir.appending(path: $0) }
    //return try await self.private?.files(baseDir: baseDir)
    //  .reduce(into: [URL]()) { $0.append($1) }
    //  .map { file in
    //    if file.isDirectory {
    //      return file
    //    } else {
    //      return file.dirURL!
    //    }
    //  }.unique
  }

  public init() {
    self.public = []
    self.private = []
  }

  public init(
    `public`: [String] = [],
    `private`: [String] = []
  ) {
    self.public = `public`
    self.private = `private`
  }

  //public init(
  //  `public`: [URL]? = nil,
  //  `private`: [URL]? = nil
  //) {
  //  if let publicHeaders = `public` {
  //    self.public = Files(include: publicHeaders)
  //  } else {
  //    self.public = nil
  //  }
  //  if let privateHeaders = `private` {
  //    self.private = Files(include: privateHeaders)
  //  } else {
  //    self.private = nil
  //  }
  //}
}

extension Headers: ExpressibleByStringLiteral {
  public init(stringLiteral: StringLiteralType) {
    self.public = [stringLiteral]
    self.private = []
  }
}

extension Headers: ExpressibleByArrayLiteral {
  public typealias ArrayLiteralElement = String

  public init(arrayLiteral: ArrayLiteralElement...) {
    self.public = arrayLiteral
    self.private = []
  }
}
