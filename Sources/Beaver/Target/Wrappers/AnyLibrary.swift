import Foundation

@TargetBaseWrapper
@TargetWrapper
@LibraryWrapper
public enum AnyLibrary: ~Copyable, Sendable {
  case c(CLibrary)

  public typealias ArtifactType = LibraryArtifactType
}

extension AnyLibrary {
  //func `as`<Lib: Library & ~Copyable, Result>(_ cb: (borrowing Lib) async throws -> Result) async throws -> Result {
  //  switch (self) {
  //    case .c(let lib):
  //      if lib is Lib {
  //        return try await cb(lib as! Lib)
  //      } else {
  //        TargetAccessError.notOfType(Lib.Type)
  //      }
  //  }
  //}

  //mutating func `as`<Lib: Library & ~Copyable, Result>(_ cb: (inout Lib) async throws -> Result) async throws -> Result {
  //  switch (self) {
  //    case .c(let lib):
  //      if lib is Lib {
  //        return try await cb(&lib as! Lib)
  //      } else {
  //        TargetAccessError.notOfType(Lib.Type)
  //      }
  //  }
  //}
}

extension AnyLibrary {
  //func asProtocol<Result>(_ cb: (borrowing any Library & ~Copyable) async throws -> Result) async throws -> Result {
  //  switch (self) {
  //    case .c(let lib): try await cb(lib)
  //  }
  //}

  //mutating func asProtocol<Result>(_ cb: (inout any Library & ~Copyable) async throws -> Result) async throws -> Result {
  //  switch (self) {
  //    case .c(let lib): try await cb(&lib as any Library & ~Copyable)
  //  }
  //}

  //func asProtocol<Result>(_ cb: (borrowing any Library & ~Copyable) throws -> Result) throws -> Result {
  //  switch (self) {
  //    case .c(let lib): try cb(lib)
  //  }
  //}

  //mutating func asProtocol<Result>(_ cb: (inout any Library & ~Copyable) throws -> Result) throws -> Result {
  //  switch (self) {
  //    case .c(let lib): try cb(&lib as any Library & ~Copyable)
  //  }
  //}
}

//extension AnyLibrary: Library {
//  public func linkAgainstLibrary(projectBuildDir: borrowing URL, artifact: LibraryArtifactType) -> [String] {
//    self.asProtocol { $0.linkAgainstLibrary(projectBuildDir: projectBuildDir, artifact: artifact) }
//  }

//  public func publicCflags(projectBaseDir: borrowing URL) async throws -> [String] {
//    try await self.asProtocol { try await $0.publicCflags(projectBaseDir: projectBaseDir) }
//  }
//}

//extension AnyLibrary: Target {
//  public var artifacts: [LibraryArtifactType] {
//    switch (self) {
//      case .c(let val): val.artifacts
//    }
//  }

//  public func build(artifact: LibraryArtifactType, projectBaseDir: borrowing URL, projectBuildDir: borrowing URL, context: borrowing Beaver) async throws {
//    switch (self) {
//      case .c(let val): try await val.build(artifact: artifact, projectBaseDir: projectBaseDir, projectBuildDir: projectBuildDir, context: context)
//    }
//  }

//  public func artifactOutputDir(projectBuildDir: borrowing URL, artifact: LibraryArtifactType) -> URL? {
//    switch (self) {
//      case .c(let val): val.artifactOutputDir(projectBuildDir: projectBuildDir, artifact: artifact)
//    }
//  }

//  public func artifactURL(projectBuildDir: borrowing URL, artifact: LibraryArtifactType) -> URL? {
//    switch (self) {
//      case .c(let val): val.artifactURL(projectBuildDir: projectBuildDir, artifact: artifact)
//    }
//  }
//}
