import Foundation
import Platform
import Utils

enum CTargetStorageKey: Equatable, Hashable {
  case publicHeaders
  case privateHeaders
  case languages
  /// TODO
  case sources
}

protocol CTarget: Target {
  var persistedStorage: PersistedStorage<CTargetStorageKey> { get }
  var _sources: Files { get }
  var headers: Headers { get }
  var extraCflags: Flags { get }
  var extraLinkerFlags: [String] { get }

  /// Execute a shell command with the given compiler for the specified language of self
  func executeCC(_ args: [String]) async throws
}

enum CTargetValidationError: Error {
  case noSources
  case collectionError(any Error)
}

struct UnsupportedArtifact<ArtifactType: Sendable & Equatable>: Error & Sendable {
  let type: ArtifactType

  init(_ type: ArtifactType) {
    self.type = type
  }
}

extension CTarget {
  // Default implementations for Target //
  public static var arguments: [Argument] {[
    .init("name", mandatory: true),
    .init("description"),
    .init("version"),
    .init("homepage"),
    .init("language"),
    .init("artifacts"),
    .init("sources", mandatory: true),
    .init("headers"),
    .init("cflags"),
    .init("linkerFlags"),
    .init("dependencies"),
  ]}

  public var buildableTarget: Bool { true }
  public var spawnsMoreThreadsWithGlobalThreadManager: Bool { true }

  public func build(baseDir: borrowing URL, buildDir: borrowing URL, context: borrowing Beaver) async throws {
    try await self.buildArtifactsAsync(baseDir: baseDir, buildDir: buildDir, context: context)
  }

  public func artifactOutputDir(projectBuildDir: URL, forArtifact artifact: ArtifactType? = nil) async throws -> URL {
    projectBuildDir.appending(path: "artifacts")
  }

  public func allLinkerFlags(context: borrowing Beaver, visited: inout Set<Dependency>) async throws -> [String] {
    let visitedPtr = UnsafeSendable(withUnsafeMutablePointer(to: &visited) { $0 })
    let ctxPtr = UnsafeSendable(withUnsafePointer(to: context) { $0 })
    var flags: [String] = []
    for dep in self.dependencies {
      if visited.contains(dep) { continue }
      visited.insert(dep)
      flags.append(contentsOf: try await context.withProjectAndLibrary(dep.library) { (project: borrowing Project, lib: borrowing any Library) async throws -> [String] in
        (try await lib.allLinkerFlags(context: ctxPtr.value.pointee, visited: &visitedPtr.value.pointee))
          + [lib.linkFlag(), "-L" + (try await lib.artifactOutputDir(projectBuildDir: project.buildDir, forArtifact: dep.artifact).path)]
      })
    }

    return self.extraLinkerFlags + flags
  }

  public func languages(context: borrowing Beaver) async throws -> [Language] {
    let ctxPtr = UnsafeSendable(withUnsafePointer(to: context) { $0 }) // only used for the duration of this function call
    return try await self.persistedStorage.storingOrRetrieving(
      key: .languages,
      try await self.dependencies.asyncFlatMap { dep in
        try await ctxPtr.value.pointee.withLibrary(dep.library) { library in
          var languages = try await library.languages(context: ctxPtr.value.pointee)
          languages.append(library.language)
          return languages
        }
      }.unique
    )
  }

  public func clean(buildDir: borrowing URL, context: borrowing Beaver) async throws {
    let objectDir = self.objectBuildDir(projectBuildDir: buildDir)
    let artifactDir = try await self.artifactOutputDir(projectBuildDir: buildDir)
    // TODO: option to use `trashItem` instead of remove?
    if objectDir.exists {
      for file in try FileManager.default.contentsOfDirectory(atPath: objectDir.path) {
        try FileManager.default.removeItem(at: objectDir.appending(path: file))
      }
    }
    if artifactDir.exists {
      for file in try FileManager.default.contentsOfDirectory(atPath: artifactDir.path) {
        try? FileManager.default.removeItem(at: artifactDir.appending(path: file))
      }
    }
    try context.fileCache!.removeTarget(target: self.ref)
  }

  // Default implementations for Library (also used for building of executables) //

  public func publicCflags() async throws -> [String] {
    self.extraCflags.public
  }

  public func publicHeaders(baseDir: URL) async throws -> [URL] {
    if let headers: [URL] = try await self.persistedStorage.getElement(withKey: .publicHeaders) {
      return headers
    } else {
      //let headers = (try await self.headers.public?.files(baseURL: baseDir).reduce(into: [URL]()) { $0.append($1) } ?? [])
        //.map { $0.dirURL! }.unique
      let headers = try await self.headers.publicHeaders(baseDir: baseDir) ?? []
      await self.persistedStorage.store(value: headers, key: .publicHeaders)
      return headers
    }
  }

  // Private Flags //

  func privateCflags(context: borrowing Beaver) async throws -> [String] {
    var dependencyCflags: [String] = []
    for dependency in self.dependencies {
      dependencyCflags.append(contentsOf: try await context.withLibrary(dependency.library) { lib in return try await lib.publicCflags() })
    }
    return self.extraCflags.private + dependencyCflags + (self.language.cflags() ?? [])
  }

  func privateHeaders(baseDir: URL, context: borrowing Beaver) async throws -> [URL] {
    if let headers: [URL] = try await self.persistedStorage.getElement(withKey: .privateHeaders) {
      return headers
    } else {
      var dependencyHeaders: [URL] = []
      for dependency in self.dependencies {
        dependencyHeaders.append(contentsOf: try await context.withLibrary(dependency.library) { lib in return try await lib.publicHeaders(baseDir: baseDir) })
      }
      //let headers = (try await self.headers.private?.files(baseURL: baseDir).reduce(into: [URL]()) { $0.append($1) } ?? []).map { $0.dirURL! }.unique + dependencyHeaders
      let headers = (try await self.headers.privateHeaders(baseDir: baseDir) ?? []) + dependencyHeaders
      await self.persistedStorage.store(value: headers, key: .privateHeaders)
      return headers
    }
  }

  // Building //

  /// output directory where object files are stored
  func objectBuildDir(projectBuildDir: URL) -> URL {
    projectBuildDir.appending(path: "objects").appending(path: self.name)
  }

  /// Get the path to the object output file for a given source file `file`
  func objectFile(baseDir: borrowing URL, buildDir: borrowing URL, file: URL, type: CObjectType) async -> URL {
    let relativePath = file.unsafeRelativePath(from: baseDir)!
    let ext: String
    switch (type) {
      case .dynamic: ext = ".dyn.o"
      case .static: ext = ".o"
    }
    return URL(fileURLWithPath: buildDir.path + PATH_SEPARATOR + relativePath + ext)
  }

  /// Build all objects of this target
  ///
  /// # Returns
  /// - the object files created
  /// - wether any of these object files were rebuilt
  func buildObjects(baseDir: URL, projectBuildDir: URL, artifact: ArtifactType, context: borrowing Beaver) async throws -> ([URL], Bool) {
    let type = artifact.cObjectType!
    //await self.persistedStorage.store(value: [URL:URL](), key: .objects) // to store in `objectFile` --> initialize once per artifact, this also means artifacts can't be built in parallell
    let cflags = (try await self.publicCflags())
      + (try await self.privateCflags(context: context))
      + (try await self.publicHeaders(baseDir: baseDir)).map { "-I\($0.path)"}
      + (try await self.privateHeaders(baseDir: baseDir, context: context)).map { "-I\($0.path)" }
    let objectBuildDir = self.objectBuildDir(projectBuildDir: projectBuildDir)
    let contextPtr = withUnsafePointer(to: context) { $0 }
    //return try await context.fileCache.loopChangedSourceFiles(
    //  self.collectSources(baseDir: baseDir),
    //  target: TargetRef(target: self.id, project: self.projectId), artifact: .library(type == .dynamic ? .dynlib : .staticlib)
    //) { source in
    //  return try await self.buildObject(baseDir: baseDir, buildDir: objectBuildDir, file: source, cflags: cflags, type: type, context: contextPtr.pointee)
    //}
    var anyChanged = false
    let objectFiles = try await context.fileCache!.loopSourceFiles(
      self.collectSources(baseDir: baseDir),
      target: TargetRef(target: self.id, project: self.projectId),
      artifact: artifact.asArtifactType()
    ) { (source, changed) async throws -> URL in
      if changed {
        anyChanged = true
        return try await self.buildObject(baseDir: baseDir, buildDir: objectBuildDir, file: source, cflags: cflags, type: type, context: contextPtr.pointee)
      } else {
        return await self.objectFile(baseDir: baseDir, buildDir: objectBuildDir, file: source, type: type)
      }
    }
    return (objectFiles, anyChanged)
    //return try await self.loopSources(baseDir: baseDir) { source in
    //  return try await self.buildObject(baseDir: baseDir, buildDir: objectBuildDir, file: source, cflags: cflags, type: type, context: contextPtr.pointee)
    //}
  }

  /// # Parameters
  /// - `file`: The source file
  ///
  /// # Returns
  /// The file where the object was outputted to
  @inline(__always)
  func buildObject(
    baseDir: borrowing URL,
    buildDir: borrowing URL,
    file: borrowing URL,
    cflags: borrowing [String],
    type: CObjectType,
    context: borrowing Beaver
  ) async throws -> URL {
    let objectFileURL = await self.objectFile(baseDir: baseDir, buildDir: buildDir, file: file, type: type)
    let baseURL = objectFileURL.dirURL!
    if !baseURL.exists { try FileManager.default.createDirectory(at: baseURL, withIntermediateDirectories: true) }

    var extraCflags: [String] = []
    if type == .dynamic { extraCflags.append("-fPIC") }
    let args = extraCflags + cflags + ["-c", file.path, "-o", objectFileURL.path]
    try await self.executeCC(args)

    return objectFileURL
  }

  // Utils //

  public func executeCC(_ args: [String]) async throws {
    switch (self.language) {
      case .objc: fallthrough
      case .objcxx:
        try await Tools.exec(Tools.objcCompiler!, args)
      case .c:
        if let extraArgs = Tools.ccExtraArgs {
          try await Tools.exec(Tools.cc!, extraArgs + args)
        } else {
          try await Tools.exec(Tools.cc!, args)
        }
      case .cxx:
        if let extraArgs = Tools.cxxExtraArgs {
          try await Tools.exec(Tools.cxx!, extraArgs + args)
        } else {
          try await Tools.exec(Tools.cxx!, args)
        }
      default:
        throw InvalidLanguage(language: self.language)
    }
  }

  func loopSources<Result>(baseDir: borrowing URL, _ cb: (URL) async throws -> Result) async throws -> [Result] {
    var output: [Result] = []
    for try await source in try self._sources.files(baseURL: baseDir) {
      output.append(try await cb(source))
    }
    return output
    // TODO: rework
    //if let sources: [URL] = try await self.persistedStorage.getElement(withKey: .sources) {
    //  for source in sources {
    //    try await cb(source)
    //  }
    //} else {
    //  var sources: [URL] = []
    //  for try await source in try self._sources.files(baseURL: baseDir) {
    //    //try await self.buildObject(baseDir: baseDir, buildDir: buildDir, file: source, type: type, context: context)
    //    try await cb(source)
    //    sources.append(source)
    //  }
    //  await self.persistedStorage.store(value: sources, key: .sources)
    //}
  }

  func collectSources(baseDir: URL) async throws -> [URL] {
    return try await self.persistedStorage.storingOrRetrieving(
      key: .sources,
      try await self._sources.files(baseURL: baseDir).reduce(into: [URL](), { $0.append($1) })
    )
  }
}
