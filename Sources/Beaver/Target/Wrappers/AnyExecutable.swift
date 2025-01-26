import Foundation

@TargetBaseWrapper
@TargetWrapper
public enum AnyExecutable: ~Copyable, Sendable {
  case c(CExecutable)

  public typealias ArtifactType = ExecutableArtifactType
}

extension AnyExecutable {
  //func `as`<Exe: Executable & ~Copyable, Result>(_ cb: (borrowing Exe) async throws -> Result) async throws -> Result {
  //  switch (self) {
  //    case .c(let lib):
  //      if lib is Exe {
  //        return try await cb(lib as! Exe)
  //      } else {
  //        TargetAccessError.notOfType(Lib.Type)
  //      }
  //  }
  //}

  //mutating func `as`<Exe: Executable & ~Copyable, Result>(_ cb: (inout Exe) async throws -> Result) async throws -> Result {
  //  switch (self) {
  //    case .c(let exe):
  //      if exe is Exe {
  //        return try await cb(&exe as! Exe)
  //      } else {
  //        TargetAccessError.notOfType(Exe.Type)
  //      }
  //  }
  //}
}

extension AnyExecutable {
  //func asProtocol<Result>(_ cb: (borrowing any Executable & ~Copyable) async throws -> Result) async throws -> Result {
  //  switch (self) {
  //    case .c(let lib): try await cb(lib)
  //  }
  //}

  //mutating func asProtocol<Result>(_ cb: (borrowing any Executable & ~Copyable) async throws -> Result) async throws -> Result {
  //  switch (self) {
  //    case .c(let lib): try await cb(&lib as any Executable & ~Copyable)
  //  }
  //}

  //func asProtocol<Result>(_ cb: (borrowing any Executable & ~Copyable) throws -> Result) throws -> Result {
  //  switch (self) {
  //    case .c(let lib): try cb(lib)
  //  }
  //}

  //mutating func asProtocol<Result>(_ cb: (borrowing any Executable & ~Copyable) throws -> Result) throws -> Result {
  //  switch (self) {
  //    case .c(let lib): try cb(&lib as any Executable & ~Copyable)
  //  }
  //}
}

extension AnyExecutable: Executable {}

//extension AnyExecutable: Target {
//  public var artifacts: [ExecutableArtifactType] {
//    switch (self) {
//      case .c(let val): val.artifacts
//    }
//  }

//  public func build(artifact: ExecutableArtifactType, projectBaseDir: borrowing URL, projectBuildDir: borrowing URL, context: borrowing Beaver) async throws {
//    switch (self) {
//      case .c(let val): try await val.build(artifact: artifact, projectBaseDir: projectBaseDir, projectBuildDir: projectBuildDir, context: context)
//    }
//  }

//  public func artifactOutputDir(projectBuildDir: borrowing URL, artifact: ExecutableArtifactType) -> URL? {
//    switch (self) {
//      case .c(let val): val.artifactOutputDir(projectBuildDir: projectBuildDir, artifact: artifact)
//    }
//  }

//  public func artifactURL(projectBuildDir: borrowing URL, artifact: ExecutableArtifactType) -> URL? {
//    switch (self) {
//      case .c(let val): val.artifactURL(projectBuildDir: projectBuildDir, artifact: artifact)
//    }
//  }
//}
