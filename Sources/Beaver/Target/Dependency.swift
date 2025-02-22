import Foundation
import Utils

public struct TargetRef: Hashable, Equatable, Sendable {
  public let target: Self.Ref
  public let project: ProjectRef

  public typealias Ref = Int

  public init(target: Int, project: ProjectRef) {
    self.target = target
    self.project = project
  }
}

extension TargetRef {
  public func description(context: Beaver) async -> String {
    let targetName = await context.targetName(self)
    let projectName = await context.projectName(self.project)
    return if context.currentProjectIndex == self.project {
      targetName
    } else {
      projectName + ":" + targetName
    }
  }
}

public struct LibraryTargetDependency: Hashable, Equatable, Sendable {
  public let target: TargetRef
  public let artifact: LibraryArtifactType

  public init(target: TargetRef, artifact: LibraryArtifactType) {
    self.target = target
    self.artifact = artifact
  }
}

public struct PkgConfigDependency: Hashable, Equatable, Sendable {
  let name: String
  let preferStatic: Bool

  public enum ValidationError: Error {
    case notExists
  }

  public init(name: String, preferStatic: Bool = false) throws {
    self.name = name
    self.preferStatic = preferStatic

    if try Tools.execWithExitCodeSync(Tools.pkgconfig!, [name, "--exists"]) == 1 {
      throw ValidationError.notExists
    }
  }

  var cflags: [String] {
    get throws {
      return Tools.parseArgs(
        try Tools.execWithOutputSync(Tools.pkgconfig!, [self.name, "--cflags", "--keep-system-cflags"]).stderr.trimmingCharacters(in: .whitespacesAndNewlines)
      ).map { String($0) }
    }
  }

  var linkerFlags: [String] {
    get throws {
      var args = [self.name, "--libs", "--keep-system-libs"]
      if self.preferStatic { args.append("--static") }
      return Tools.parseArgs(
        try Tools.execWithOutputSync(Tools.pkgconfig!, args).stderr.trimmingCharacters(in: .whitespacesAndNewlines)
      ).map { String($0) }
    }
  }
}

public enum Dependency: Hashable, Equatable, Sendable {
  case library(LibraryTargetDependency)
  case pkgconfig(PkgConfigDependency)
  case system(String)
  case customFlags(cflags: [String], linkerFlags: [String])
  /// reference can be found in reply of API
  case cmakeId(String)

  public enum ParsingError: Error {
    case unexpectedNoComponents
    case malformed(String)
    /// No project exists with the specified name
    case unknownProject(String)
    case unknownTarget(name: String, inProject: String)
    case noDefaultProject
    /// The library contains no artifacts that can be linked to
    case noLinkableArtifacts(libraryName: String)
  }

  var type: DependencyType {
    switch (self) {
      case .library(_): .library
      case .pkgconfig(_): .pkgconfig
      case .system(_): .system
      case .customFlags(cflags: _, linkerFlags: _): .customFlags
      case .cmakeId(_): .cmakeId
    }
  }
}

enum DependencyType: Int {
  case library
  case pkgconfig
  case system
  case customFlags
  case cmakeId
}

extension Dependency {
  var isBuildable: Bool {
    switch (self) {
      case .library(_): fallthrough
      case .cmakeId(_):
        return true
      case .pkgconfig(_): fallthrough
      case .system(_): fallthrough
      case .customFlags(cflags: _, linkerFlags: _):
        return false
    }
  }

  /// Both linker and header files
  public func cflags(context: Beaver) async throws -> [String]? {
    switch (self) {
      case .library(let libTarget):
        return try await context.withProjectAndLibrary(libTarget.target) { (project: borrowing AnyProject, library: borrowing AnyLibrary) in
          return try await library.publicCflags(projectBaseDir: project.baseDir)
        }
      case .pkgconfig(let dep):
        return try dep.cflags
      case .system(_):
        return nil
      case .customFlags(cflags: let cflags, linkerFlags: _):
        return cflags
      case .cmakeId(let cmakeId):
        return try await context.withProjectAndLibrary(cmakeId: cmakeId) { (project: borrowing CMakeProject, library: borrowing CMakeLibrary) in
          return try await library.publicCflags(projectBaseDir: project.baseDir)
        }
    }
  }

//  public func cflagsAndHeaders(context: borrowing Beaver) async throws -> ([String], [URL]?)? {
//    switch (self) {
//      case .library(let libTarget):
//        return try await context.withProjectAndLibrary(libTarget.target) { (project: borrowing AnyProject, library: borrowing AnyLibrary) in
//          switch (library) {
//            case .c(let lib):
//              return try await lib.publicCflagsAndHeaders(projectBaseDir: project.baseDir)
//            case .cmake(let lib):
//              return (try await lib.publicCflags(projectBaseDir: project.baseDir), nil)
//          }
//        }
//      case .pkgconfig(let dep):
//        return try dep.cflags
//      case .system(_):
//        return nil
//      case .customFlags(cflags: let cflags, linkerFlags: _):
//        return cflags
//      case .cmakeId(let cmakeId):
//        return try await context.withProjectAndLibrary(cmakeId: cmakeId) { (project: borrowing CMakeProject, library: borrowing CMakeLibrary) in
//          return (try await library.publicCflags(projectBaseDir: project.baseDir), nil)
//        }
//    }
//  }

//  @available(*, deprecated, message: "use linkerFlagsAndArtifactURL(context:, collectingLanguageIn:)")
//  public func linkerFlags(context: borrowing Beaver) async throws -> [String] {
//    switch (self) {
//      case .library(let libTarget):
//        return await context.withProjectAndLibrary(libTarget.target) { (project: borrowing AnyProject, library: borrowing AnyLibrary) in
//          return library.linkAgainstLibrary(projectBuildDir: project.buildDir, artifact: libTarget.artifact)
//        }
//      case .pkgconfig(let dep):
//        return try dep.linkerFlags
//      case .system(let name):
//        return ["-l\(name)"]
//      case .customFlags(cflags: _, linkerFlags: let linkerFlags):
//        return linkerFlags
//      case .cmakeId(let cmakeId):
//        return try await context.withProjectAndLibrary(cmakeId: cmakeId) { (project: borrowing CMakeProject, library: borrowing CMakeLibrary) in
//          return library.linkAgainstLibrary(projectBuildDir: project.buildDir)
//        }
//    }
//  }

  /// Returns the linker flags (first argument) and the artifactURL being linked to (if the dependency is a target
  /// defined in Beaver)
  public func linkerFlags(context: Beaver, collectingLanguageIn langs: inout Set<Language>) async throws -> [String] {
    switch (self) {
      case .library(let libTarget):
        let contextPtr = withUnsafePointer(to: context) { $0 }
        return await context.withProjectAndLibrary(libTarget.target) { (project: borrowing AnyProject, library: borrowing AnyLibrary) in
          langs.insert(library.language)
          return library.linkAgainstLibrary(projectBuildDir: project.buildDir(contextPtr.pointee), artifact: libTarget.artifact)
        }
      case .pkgconfig(let dep):
        return try dep.linkerFlags
      case .system(let name):
        return ["-l\(name)"]
      case .customFlags(cflags: _, linkerFlags: let linkerFlags):
        return linkerFlags
      case .cmakeId(let cmakeId):
        let contextPtr = withUnsafePointer(to: context) { $0 }
        return try await context.withProjectAndLibrary(cmakeId: cmakeId) { (project: borrowing CMakeProject, library: borrowing CMakeLibrary) in
          langs.insert(library.language)
          return library.linkAgainstLibrary(projectBuildDir: project.buildDir(contextPtr.pointee))
        }
    }
  }
}

extension Beaver {
  public func evaluateTarget(targetName target: String) async throws -> TargetRef {
    let components = target.split(separator: ":")
    switch (components.count) {
      case 0:
        throw Dependency.ParsingError.unexpectedNoComponents
      case 1:
        guard let currentProject = self.currentProjectIndex else {
          throw Dependency.ParsingError.noDefaultProject
        }
        guard let targetIndex = await self.targetIndex(name: target, project: currentProject) else {
          let projectName = await self.projectName(currentProject)
          throw Dependency.ParsingError.unknownTarget(name: target, inProject: projectName)
        }
        return TargetRef(target: targetIndex, project: currentProject)
      case 2:
        let name = String(components[1])
        let projectName = String(components[0])
        guard let projectIndex = await self.projectIndex(name: projectName) else {
          throw Dependency.ParsingError.unknownProject(projectName)
        }
        guard let targetIndex = await self.targetIndex(name: name, project: projectIndex) else {
          throw Dependency.ParsingError.unknownTarget(name: name, inProject: projectName)
        }
        return TargetRef(target: targetIndex, project: projectIndex)
      default:
        throw Dependency.ParsingError.malformed(target)
    }
  }

  public func dependency(_ target: String, artifact: LibraryArtifactType?) async throws -> Dependency {
    let target = try await self.evaluateTarget(targetName: target)
    let artifactType = if let artifact = artifact {
      artifact
    } else {
      try await self.defaultLibraryArtifact(target)
    }
    return .library(LibraryTargetDependency(
      target: target,
      artifact: artifactType
    ))
  }

  public func dependency(targetRef: TargetRef, artifact: LibraryArtifactType?) async throws -> Dependency {
    let artifactType = if let artifact = artifact {
      artifact
    } else {
      try await self.defaultLibraryArtifact(targetRef)
    }
    return Dependency.library(LibraryTargetDependency(
      target: targetRef,
      artifact: artifactType
    ))
  }

  public func defaultLibraryArtifact(_ target: TargetRef) async throws -> LibraryArtifactType {
    try await self.withProjectAndLibrary(target) { (project, library) in
      let order: [LibraryArtifactType] = if project.id == self.currentProjectIndex {
        [.staticlib, .dynlib]
      } else {
        [.dynlib, .staticlib]
      }
      guard let artifact = order.first(where: { library.artifacts.contains($0) }) else {
        throw Dependency.ParsingError.noLinkableArtifacts(libraryName: await self.targetName(target))
      }
      return artifact
    }
  }
}
