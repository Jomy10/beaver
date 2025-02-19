import Foundation
import Platform
import Utils

public protocol CTarget: Target, ~Copyable {
  var sources: Files { get }
  var headers: Headers { get }
  var extraCFlags: Flags { get }
  var extraLinkerFlags: [String] { get }

  static var defaultArtifacts: [ArtifactType] { get }
}

// Default implementations for Target
extension CTarget where Self: ~Copyable {
  public func artifactOutputDir(projectBuildDir: URL, artifact: ArtifactType) -> URL? {
    projectBuildDir.appending(path: "artifacts")
  }
}

extension CTarget where Self: ~Copyable {
  /// Returns dependency linker flags and updates the cache for the artifact
  func dependencyLinkerFlags(context: borrowing Beaver) async throws -> [String] {
    // Collect linker flags to link against dependencies
    var depLinkerFlags: [String] = []
    var depLanguages: Set<Language> = Set()
    let contextPtr = withUnsafePointer(to: context) { $0 }
    try await self.loopUniqueDependenciesRecursive(context: context) { dependency in
      let flags = try await dependency.linkerFlags(context: contextPtr.pointee, collectingLanguageIn: &depLanguages)
      depLinkerFlags.append(contentsOf: flags)
    }

    return depLinkerFlags + depLanguages.compactFlatMap { Language.linkerFlags(from: $0, to: self.language) }
  }

  func objectBuildDir(projectBuildDir: borrowing URL) -> URL {
    projectBuildDir.appending(path: "objects").appending(path: self.name)
  }

  func objectFile(projectBaseDir: borrowing URL, objectBuildDir: borrowing URL, sourceFile file: borrowing URL, type: CObjectType) -> URL {
    let relativePathToSource = file.unsafeRelativePath(from: projectBaseDir)!
    let ext: String = switch (type) {
      case .dynamic: ".dyn.o"
      case .static: ".o"
    }
    return URL(filePath: objectBuildDir.path + PATH_SEPARATOR + relativePathToSource + ext)
  }

  func executeCC(_ args: [String]) async throws {
    switch (self.language) {
      case .objc: fallthrough
      case .objcxx:
        try await Tools.exec(Tools.objcCompiler!, args, context: self.name)
      case .c:
        var extraArgs = Tools.ccExtraArgs ?? []
        if Tools.enableColor {
          extraArgs.append("-fdiagnostics-color=always")
        }
        try await Tools.exec(Tools.cc!, extraArgs + args, context: self.name)
      case .cxx:
        var extraArgs = Tools.cxxExtraArgs ?? []
        if Tools.enableColor {
          extraArgs.append("-fdiagnostics-color=always")
        }
        try await Tools.exec(Tools.cxx!, extraArgs + args, context: self.name)
      //default:
      //  throw TargetValidationError(self, .invalidLanguage(self.language))
    }
  }

  func collectSources(projectBaseDir: borrowing URL) async throws -> [URL] {
    guard let sources = try await self.sources.files(baseDir: projectBaseDir)?.reduce(into: [URL](), { $0.append($1) }) else {
      throw TargetValidationError(self, .noSources)
    }
    if sources.count == 0 {
      throw TargetValidationError(self, .noSources)
    }
    return sources
  }

  public func publicCflags(projectBaseDir: borrowing URL) async throws -> [String] {
    self.extraCFlags.public + self.headers.publicHeaders(baseDir: projectBaseDir).map { "-I\($0.path)" }
  }

  /// Only used when compiling objects of this target
  public func privateCflags(projectBaseDir: borrowing URL, context: borrowing Beaver) async throws -> [String] {
    var dependencyCflags: [String] = []
    for dependency in self.dependencies {
      guard let cflags = try await dependency.cflags(context: context) else { continue }
      dependencyCflags.append(contentsOf: cflags)
    }

    return self.extraCFlags.private
      + dependencyCflags
      + (self.headers.privateHeaders(baseDir: projectBaseDir).map({ "-I\($0.path)" }))
  }

  var ccRule: String {
    self.language.compileRule
  }

  var linkRule: String {
    self.language.linkRule
  }

  /// All cflags for this target. Includes dependency's cflags. Includes header include paths. Used when compiling
  public func cflags(projectBaseDir: borrowing URL, context: borrowing Beaver) async throws -> [String] {
    var flags = try await self.publicCflags(projectBaseDir: projectBaseDir)
      + self.privateCflags(projectBaseDir: projectBaseDir, context: context)
      + context.optimizeMode.cflags
    if Tools.enableColor {
      flags.append("-fdiagnostics-color=always")
    }
    return flags
  }

  /// Commands for building dependencies used in ninja build script
  func dependencyCommands(context: borrowing Beaver) async throws -> [String] {
    let contextPtr = UnsafeSendable(withUnsafePointer(to: context) { $0 })
    return try await self.dependencies.async.compactMap { dep in
      switch (dep) {
        case .library(let lib):
          let (projectName, targetName) = await contextPtr.value.pointee.projectAndTargetName(lib.target)
          return "\(projectName)$:\(targetName)$:\(lib.artifact)"
        case .pkgconfig(_): fallthrough
        case .system(_): fallthrough
        case .customFlags(cflags: _, linkerFlags: _):
          return nil
        case .cmakeId(let id):
          return try await contextPtr.value.pointee.withProjectAndLibrary(cmakeId: id) { (project: borrowing CMakeProject, library: borrowing CMakeLibrary) in
            return "\(project.name)$:\(library.name)"
          }
      }
    }.reduce(into: [String]()) { (acc, depName) in
      acc.append(depName)
    }
  }
}
