import Foundation
import Platform
import Utils

public protocol CTarget: Target, ~Copyable {
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
extension CTarget where Self: ~Copyable {
  //public func buildAsync(
  //  projectBaseDir: borrowing URL,
  //  projectBuildDir: borrowing URL,
  //  context: borrowing Beaver
  //) async throws {
  //  try await self.buildArtifactsAsync(baseDir: projectBaseDir, buildDir: projectBuildDir, context: context)
  //}

//  public func clean(projectBuildDir: borrowing URL, context: borrowing Beaver) async throws {
//    let objectDir = self.objectBuildDir(projectBuildDir: projectBuildDir)
//    let artifactDir = self.artifactOutputDir(projectBuildDir: projectBuildDir, artifact: self.artifacts.first!)!
//
//    // TODO: option to use `trashItem` instead of remove?
//    if FileManager.default.exists(at: objectDir) {
//      for file in try FileManager.default.contentsOfDirectory(atPath: objectDir.path) {
//        try FileManager.default.removeItem(at: objectDir.appending(path: file))
//      }
//    }
//
//    if FileManager.default.exists(at: artifactDir) {
//      for file in try FileManager.default.contentsOfDirectory(atPath: artifactDir.path) {
//        try? FileManager.default.removeItem(at: artifactDir.appending(path: file))
//      }
//    }
//
//    //try context.fileCache!.removeTarget(target: self.ref)
//  }

  public func artifactOutputDir(projectBuildDir: URL, artifact: ArtifactType) -> URL? {
    projectBuildDir.appending(path: "artifacts")
  }
}

extension CTarget where Self: ~Copyable {
  /// Build all objects of this target
  ///
  /// # Returns
  /// - the object files (both created and already existing)
  /// - wether any of these object files were rebuilt
  //func buildObjects(
  //  projectBaseDir: borrowing URL,
  //  projectBuildDir: borrowing URL,
  //  artifact: ArtifactType,
  //  context: borrowing Beaver
  //) async throws -> ([URL], Bool) {
  //  let type = artifact.cObjectType!

  //  let (cflags, headers) = try await self.cflagsAndHeaders(projectBaseDir: projectBaseDir, context: context)
  //  let objectBuildDir = self.objectBuildDir(projectBuildDir: projectBuildDir)

  //  var anyChanged = false
  //  let contextPtr = withUnsafePointer(to: context) { $0 }
  //  let sources = try await self.collectSources(projectBaseDir: projectBaseDir)
  //  try await self.storeCache(sourceFiles: sources, includePaths: headers, context: context)
  //  let objectFiles = try await context.fileCache!.loopFiles(
  //    sources,
  //    target: self.ref,
  //    artifact: artifact.asArtifactType()
  //  ) { [projectBaseDir = copy projectBaseDir] source, changed in
  //    let objectFile = self.objectFile(projectBaseDir: projectBaseDir, objectBuildDir: objectBuildDir, sourceFile: source, type: type)
  //    try await self.storeCache(objectFile: objectFile, context: context)
  //    if changed || !FileManager.default.exists(at: objectFile) {
  //      anyChanged = true
  //      try await self.buildObject(
  //        projectBaseDir: projectBaseDir,
  //        objectBuildDir: objectBuildDir,
  //        sourceFile: source,
  //        objectFile: objectFile,
  //        cflags: cflags,
  //        type: type,
  //        context: contextPtr.pointee)
  //    }
  //    return objectFile
  //  }
  //  return (objectFiles, anyChanged)
  //}

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

  //@inline(__always)
  //func buildObject(
  //  projectBaseDir: borrowing URL,
  //  objectBuildDir: borrowing URL,
  //  sourceFile file: borrowing URL,
  //  objectFile: borrowing URL,
  //  cflags: borrowing [String],
  //  type: CObjectType,
  //  context: borrowing Beaver
  //) async throws {
  //  let objectFileBase = objectFile.dirURL!
  //  try FileManager.default.createDirectoryIfNotExists(at: objectFileBase)

  //  var extraCflags = [String]()
  //  if type == .dynamic { extraCflags.append("-fPIC") }
  //  let args = extraCflags + cflags + ["-c", file.path, "-o", objectFile.path]
  //  try await self.executeCC(args)
  //}

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
    if sources.count == 0 {
      throw TargetValidationError(self, .noSources)
    }
    return sources
  }

  public func publicCflags(projectBaseDir: borrowing URL) async throws -> [String] {
    self.extraCFlags.public + self.headers.publicHeaders(baseDir: projectBaseDir).map { "-I\($0.path)" }
  }

//  @available(*, deprecated)
//  func publicCflagsAndHeaders(projectBaseDir: borrowing URL) async throws -> ([String], [URL]) {
//    let headers = self.headers.publicHeaders(baseDir: projectBaseDir)
//    return (self.extraCFlags.public) + (headers.map { "-I\($0.path)" })
//  }

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

  //@available(*, deprecated)
  //func privateCflagsAndHeaders(projectBaseDir: borrowing URL, context: borrowing Beaver) async throws -> ([String], [URL]) {
  //  var dependencyCflags: [String] = []
  //  var dependencyHeaders: [URL] = []
  //  for dependency in self.dependencies {
  //    guard let (cflags, headers) = try await dependency.cflags(context: context) else { continue }
  //    dependencyCflags.append(contentsOf: cflags)
  //    if let headers = headers {
  //      dependencyHeaders.append(contentsOf: headers)
  //    }
  //  }

  //  var cflags: [String] = self.extraCFlags.private
  //    + dependencyCflags
  //  if let langFlags = self.language.cflags() {
  //    cflags.append(contentsOf: langFlags)
  //  }
  //  let headers = self.headers.privateHeaders(baseDir: projectBaseDir)
  //  return (cflags + headers.map({ "-I\($0.path)" }), headers + dependencyHeaders)
  //}

  var ccRule: String {
    switch (self.language) {
      case .c: "cc"
      case .cxx: "cxx"
      case .objc: "objcc"
      case .objcxx: "objcxx"
    }
  }

  //lazy var ccExtraArgs: [String]? = switch (self.language) {
  //  case .c: Tools.ccExtraArgs
  //  case .cxx: Tools.cxxExtraArgs
  //  default: nil
  //}

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

  //@available(*, deprecated, message: "not used anymore")
  //func cflagsAndHeaders(projectBaseDir: borrowing URL, context: borrowing Beaver) async throws -> ([String], [URL]) {
  //  let (flags, headers) = try await self.publicCflagsAndHeaders(projectBaseDir: projectBaseDir)
  //  let (pFlags, pHeaders) = try await self.privateCflagsAndHeaders(projectBaseDir: projectBaseDir, context: context)
  //  return (flags + pFlags + context.optimizeMode.cflags, headers + pHeaders)
  //}

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

  //public func debugString(_ opts: DebugTargetOptions) -> String {
  //  var str = """
  //  \(self.name)
  //  """

  //  if opts.flags {
  //    str += "\n  cflags: \(self.extraCFlags)"
  //    str += "\n  linkerFlags: \(self.extraLinkerFlags)"
  //    str += "\n  headers: \(self.headers)"
  //  }

  //  str += "\n  artifacts: \(self.artifacts)"

  //  return str
  //}
}
