import Foundation
import Platform
import Utils

public protocol CTarget: Target {
  var sources: Files { get }
  var headers: Headers { get }
  var extraCFlags: Flags { get }
  var extraLinkerFlags: [String] { get }

  static var defaultArtifacts: [ArtifactType] { get }

  /// All cflags for this target. Includes dependency's cflags. Includes header include paths. Used when compiling
  //func cflags(projectBaseDir: borrowing URL, context: borrowing Beaver) async throws -> [String]

  // TODO: check if we still need this
  //var storage: AsyncRWLock<Storage> { get }
}

//public final class CTargetStorage {
//  var sources: [URL]? = nil
//  //TODO var cflags: [String]? = nil
//}

// Default implementations for Target
extension CTarget {
  public func build(projectBaseDir: borrowing URL, projectBuildDir: borrowing URL, context: borrowing Beaver) async throws {
    try await self.buildArtifactsSync(baseDir: projectBaseDir, buildDir: projectBuildDir, context: context)
  }

  public func clean(projectBuildDir: borrowing URL, context: borrowing Beaver) async throws {
    let objectDir = self.objectBuildDir(projectBuildDir: projectBuildDir)
    let artifactDir = self.artifactOutputDir(projectBuildDir: projectBuildDir, artifact: self.artifacts.first!)!
    //var artifactDirs = Set<URL>()
    //for await artifact in (
    //  self.artifacts.async
    //    .map { try await self.artifactOutputDir(projectBuildDir: projectBuildDir, artifact: $0) }
    //) {
    //  artifactDirs
    //}
    // TODO: option to use `trashItem` instead of remove?
    if FileManager.default.exists(at: objectDir) {
      for file in try FileManager.default.contentsOfDirectory(atPath: objectDir.path) {
        try FileManager.default.removeItem(at: objectDir.appending(path: file))
      }
    }
    //for artifactDir in artifactDirs {
    if FileManager.default.exists(at: artifactDir) {
      for file in try FileManager.default.contentsOfDirectory(atPath: artifactDir.path) {
        try? FileManager.default.removeItem(at: artifactDir.appending(path: file))
      }
    }
    //}
    try context.fileCache!.removeTarget(target: self.ref)
  }

  public func artifactOutputDir(projectBuildDir: URL, artifact: ArtifactType) -> URL? {
    projectBuildDir.appending(path: "artifacts")
  }
}

extension CTarget {
  //public typealias Storage = CTargetStorage

  /// Build all objects of this target
  ///
  /// # Returns
  /// - the object files (both created and already existing)
  /// - wether any of these object files were rebuilt
  func buildObjects(
    projectBaseDir: URL,
    projectBuildDir: URL,
    artifact: ArtifactType,
    context: borrowing Beaver
  ) async throws -> ([URL], Bool) {
    let type = artifact.cObjectType!

    let cflags = try await self.cflags(projectBaseDir: projectBaseDir, context: context)
    let objectBuildDir = self.objectBuildDir(projectBuildDir: projectBuildDir)

    var anyChanged = false
    let contextPtr = withUnsafePointer(to: context) { $0 }
    let sources = try await self.collectSources(projectBaseDir: projectBaseDir)
    let objectFiles = try await context.fileCache!.loopSourceFiles(
      sources,
      target: self.ref,
      artifact: artifact.asArtifactType()
    ) { source, changed in
      if changed {
        anyChanged = true
        return try self.buildObject(projectBaseDir: projectBaseDir, objectBuildDir: objectBuildDir, sourceFile: source, cflags: cflags, type: type, context: contextPtr.pointee)
      } else {
        return self.objectFile(projectBaseDir: projectBaseDir, objectBuildDir: objectBuildDir, sourceFile: source, type: type)
      }
    }
    return (objectFiles, anyChanged)
  }

  @inline(__always)
  func buildObject(
    projectBaseDir: borrowing URL,
    objectBuildDir: borrowing URL,
    sourceFile file: borrowing URL,
    cflags: borrowing [String],
    type: CObjectType,
    context: borrowing Beaver
  ) throws -> URL {
    let objectFileURL = self.objectFile(projectBaseDir: projectBaseDir, objectBuildDir: objectBuildDir, sourceFile: file, type: type)
    let objectFileBase = objectFileURL.dirURL!
    try FileManager.default.createDirectoryIfNotExists(at: objectFileBase)

    var extraCflags = [String]()
    if type == .dynamic { extraCflags.append("-fPIC") }
    let args = extraCflags + cflags + ["-c", file.path, "-o", objectFileURL.path]
    try self.executeCC(args)

    return objectFileURL
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

  func executeCC(_ args: [String]) throws {
    switch (self.language) {
      case .objc: fallthrough
      case .objcxx:
        try Tools.exec(Tools.objcCompiler!, args, context: self.name)
      case .c:
        if let extraArgs = Tools.ccExtraArgs {
          try Tools.exec(Tools.cc!, extraArgs + args, context: self.name)
        } else {
          try Tools.exec(Tools.cc!, args, context: self.name)
        }
      case .cxx:
        if let extraArgs = Tools.cxxExtraArgs {
          try Tools.exec(Tools.cxx!, extraArgs + args, context: self.name)
        } else {
          try Tools.exec(Tools.cxx!, args, context: self.name)
        }
      default:
        throw TargetValidationError(self, .invalidLanguage(self.language))
    }
  }

  //func loopSources<Result>(projectBaseDir: borrowing URL, _ cb: (borrowing URL) async throws -> Result) async throws -> [Result] {
  //  var output: [Result] = []
  //  if let sources = await self.storage.read({ $0.sources }) {
  //    for source in sources {
  //      output.append(try await cb(source))
  //    }
  //  } else {
  //    try await self.storage.write { storage in
  //      storage.sources = []
  //      for try await source in try self.sources.files(baseURL: projectBaseDir) {
  //        output.append(try await cb(source))
  //        storage.sources.append(source)
  //      }
  //    }
  //  }
  //  return output
  //}

  func collectSources(projectBaseDir: borrowing URL) async throws -> [URL] {
    //if let sources = await self.storage.read({ $0.sources }) {
    //  return sources
    //} else {
    //  return self.storage.write { storage in
        /*storage.sources = try await self.sources.files(baseDir: projectBaseDir)?.reduce(into: [URL](), { $0.append($1) })*/
        //return storage.sources
    //  }
    //}
    guard let sources = try await self.sources.files(baseDir: projectBaseDir)?.reduce(into: [URL](), { $0.append($1) }) else {
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

    var cflags: [String] = self.extraCFlags.private
      + dependencyCflags
      + (self.headers.privateHeaders(baseDir: projectBaseDir).map({ "-I\($0.path)" }))
    if let langFlags = self.language.cflags() {
      cflags.append(contentsOf: langFlags)
    }
    return cflags
  }

  /// All cflags for this target. Includes dependency's cflags. Includes header include paths. Used when compiling
  public func cflags(projectBaseDir: borrowing URL, context: borrowing Beaver) async throws -> [String] {
    try await self.publicCflags(projectBaseDir: projectBaseDir)
      + self.privateCflags(projectBaseDir: projectBaseDir, context: context)
  }

  //public func allLinkerFlags(context: borrowing Beaver, visited: inout Set<Dependency>) async throws -> [String] {
  //  let visitedPtr = UnsafeSendable(withUnsafeMutablePointer(to: &visited) { $0 })
  //  let ctxPtr = UnsafeSendable(withUnsafePointer(to: context) { $0 })
  //  var flags: [String] = []
  //  for dep in self.dependencies {
  //    if visited.contains(dep) { continue }
  //    visited.insert(dep)
  //    flags.append(contentsOf: try await context.withProjectAndLibrary(dep.library) { (project: borrowing Project, lib: borrowing any Library) async throws -> [String] in
  //      (try await lib.allLinkerFlags(context: ctxPtr.value.pointee, visited: &visitedPtr.value.pointee))
  //        + [lib.linkFlag(), "-L" + (try await lib.artifactOutputDir(projectBuildDir: project.buildDir, forArtifact: dep.artifact)!.path)]
  //    })
  //  }

  //  return self.extraLinkerFlags + flags
  //}
}
