import Foundation

//@EnumWrapper(TargetBase)
@TargetBaseWrapper
public enum AnyTarget: ~Copyable, Sendable {
  case library(AnyLibrary)
  case executable(AnyExecutable)
}

public enum TargetAccessError: Error {
  /// The target doesn't exist
  case noTarget(named: String)
  /// The target exists, but is not a library
  case notALibrary(named: String)
  /// The target exists, but is not an executable
  case notAnExecutable(named: String)
  /// The target exists, but is not a library
  case notLibrary
  case notExecutable

  case notOfType((any Target & ~Copyable).Type)

  case noCMakeLibrary(cmakeId: String)
}

//extension AnyTarget {
//  func asProtocol<Result>(_ cb: (borrowing any Target & ~Copyable) async throws -> Result) async rethrows -> Result {
//    switch (self) {
//      case .library(let lib): try await cb(lib as any Target & ~Copyable)
//      case .executable(let exe): try await cb(exe as any Target & ~Copyable)
//    }
//  }

//  mutating func asProtocol<Result>(_ cb: (inout any Target & ~Copyable) async throws -> Result) async rethrows -> Result {
//    switch (self) {
//      case .library(let lib): try await cb(&lib as any Target & ~Copyable)
//      case .executable(let exe): try await cb(&exe as any Targe & ~Copyable)
//    }
//  }

//  func asProtocol<Result>(_ cb: (borrowing any Target & ~Copyable) throws -> Result) rethrows -> Result {
//    switch (self) {
//      case .library(let lib): try cb(lib as any Target & ~Copyable)
//      case .executable(let exe): try cb(exe as any Target & ~Copyable)
//    }
//  }

//  mutating func asProtocol<Result>(_ cb: (inout any Target & ~Copyable) throws -> Result) rethrows -> Result {
//    switch (self) {
//      case .library(let lib): try cb(&lib as Target & ~Copyable)
//      case .executable(let exe): try cb(&exe as Target & ~Copyable)
//    }
//  }

//  func asBaseProtocol<Result>(_ cb: (borrowing any TargetBase & ~Copyable) async throws -> Result) async rethrows -> Result {
//    switch (self) {
//      case .library(let lib): try await cb(lib as any TargetBase & ~Copyable)
//      case .executable(let exe): try await cb(exe as any TargetBase & ~Copyable)
//    }
//  }

//  mutating func asBaseProtocol<Result>(_ cb: (inout any TargetBase & ~Copyable) async throws -> Result) async rethrows -> Result {
//    switch (self) {
//      case .library(let lib): try await cb(lib as any TargetBase & ~Copyable)
//      case .executable(let exe): try await cb(exe as any TargetBase & ~Copyable)
//    }
//  }

//  func asBaseProtocol<Result>(_ cb: (borrowing any TargetBase & ~Copyable) throws -> Result) rethrows -> Result {
//    switch (self) {
//      case .library(let lib): try cb(lib as any TargetBase & ~Copyable)
//      case .executable(let exe): try cb(exe as any TargetBase & ~Copyable)
//    }
//  }

//  mutating func asBaseProtocol<Result>(_ cb: (inout any TargetBase & ~Copyable) throws -> Result) rethrows -> Result {
//    switch (self) {
//      case .library(var lib): try cb(&lib)
//      case .executable(var exe): try cb(&exe)
//    }
//  }
//}

//extension AnyTarget: TargetBase {
//  var name: String { self.asBaseProtocol { $0.name } }
//  var description: String? { self.asBaseProtocol { $0.description } }
//  var homepage: URL? { self.asBaseProtocol { $0.homepage } }
//  var version: Version? { self.asBaseProtocol { $0.version } }
//  var license: String? { self.asBaseProtocol { $0.license } }
//  var language: Language { self.asBaseProtocol { $0.language } }

//  var id: Int {
//    get { self.asBaseProtocol { $0.id } }
//    set { self.asBaseProtocol { $0.id = newValue } }
//  }
//  var projectId: ProjectRef {
//    get { self.asBaseProtocol { $0.projectId } }
//    set { self.asBaseProtocol { $0.projectId = newValue } }
//  }

//  var dependencies: [Dependency] { self.asBaseProtocol { $0.dependencies } }

//  borrowing func build(
//    projectBaseDir: borrowing URL,
//    projectBuildDir: borrowing URL,
//    context: borrowing Beaver
//  ) async throws {
//    try await self.asBaseProtocol { target in
//      try await target.build(
//        projectBaseDir: projectBaseDir,
//        projectBuildDir: projectBuildDir,
//        context: context
//      )
//    }
//  }

//  func buildAsync(
//    projectBaseDir: borrowing URL,
//    projectBuildDir: borrowing URL,
//    context: borrowing Beaver
//  ) async throws {
//    try await self.asBaseProtocol { target in
//      try await target.buildAsync(
//        projectBaseDir: projectBaseDir,
//        projectBuildDir: projectBuildDir,
//        context: context
//      )
//    }
//  }

//  func build(
//    artifact: ArtifactType,
//    projectBaseDir: borrowing URL,
//    projectBuildDir: borrowing URL,
//    context: borrowing Beaver
//  ) async throws {
//    try await self.asBaseProtocol { target in
//      try await target.build(
//        artifact: artifact,
//        projectBaseDir: projectBaseDir,
//        projectBuildDir: projectBuildDir,
//        context: context
//      )
//    }
//  }

//  func clean(projectBuildDir: borrowing URL, context: borrowing Beaver) async throws {
//    try await self.asBaseProtocol { target in
//      try await target.clean(projectBuildDir: projectBuildDir, context: context)
//    }
//  }
//}
