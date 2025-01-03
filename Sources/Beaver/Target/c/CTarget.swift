import Foundation
import Platform

enum CTargetStorageKey: Equatable, Hashable {
  case publicHeaders
  case privateHeaders
  /// TODO
  case sources
}

enum CObjectType: Equatable, Hashable {
  case dynamic
  case `static`
}

protocol CTarget: Target {
  var persistedStorage: PersistedStorage<CTargetStorageKey> { get }
  var _sources: Files { get }
  var headers: Headers { get }
  var extraCflags: Flags { get }
  var extraLinkerFlags: [String] { get }

  func executeCC(_ args: [String]) async throws
}

struct UnsupportedArtifact<ArtifactType: Sendable & Equatable>: Error & Sendable {
  let type: ArtifactType

  init(_ type: ArtifactType) {
    self.type = type
  }
}

extension CTarget {
  // Default implementations for Target //
  public var buildableTarget: Bool { true }
  public var useDependencyGraph: Bool { true }
  public var spawnsMoreThreadsWithGlobalThreadManager: Bool { true }

  public func build(baseDir: borrowing URL, buildDir: borrowing URL, context: borrowing Beaver) async throws {
    try await self.buildArtifactsAsync(baseDir: baseDir, buildDir: buildDir, context: context)
  }

  public func artifactOutputDir(projectBuildDir: URL, forArtifact artifact: ArtifactType?) async throws -> URL {
    projectBuildDir.appending(path: self.name).appending(path: "artifacts")
  }

  public func allLinkerFlags(context: borrowing Beaver, visited: inout Set<LibraryRef>) async throws -> [String] {
    let visitedPtr = UnsafeSendable(withUnsafeMutablePointer(to: &visited) { $0 })
    let ctxPtr = UnsafeSendable(withUnsafePointer(to: context) { $0 })
    var flags: [String] = []
    for dep in self.dependencies {
      if visited.contains(dep) { continue }
      visited.insert(dep)
      flags.append(contentsOf: try await context.withProjectAndLibrary(dep) { (project: borrowing Project, lib: borrowing any Library) async throws -> [String] in
        (try await lib.allLinkerFlags(context: ctxPtr.value.pointee, visited: &visitedPtr.value.pointee))
          + [lib.linkFlag(), "-L" + (try await lib.artifactOutputDir(projectBuildDir: project.buildDir, forArtifact: dep.artifact).path)]
      })
    }

    return self.extraLinkerFlags + flags
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
      dependencyCflags.append(contentsOf: try await context.withLibrary(dependency) { lib in return try await lib.publicCflags() })
    }
    return self.extraCflags.private + dependencyCflags
  }

  func privateHeaders(baseDir: URL, context: borrowing Beaver) async throws -> [URL] {
    if let headers: [URL] = try await self.persistedStorage.getElement(withKey: .privateHeaders) {
      return headers
    } else {
      var dependencyHeaders: [URL] = []
      for dependency in self.dependencies {
        dependencyHeaders.append(contentsOf: try await context.withLibrary(dependency) { lib in return try await lib.publicHeaders(baseDir: baseDir) })
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
    projectBuildDir.appending(path: self.name).appending(path: "objects")
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
  /// the object files created
  func buildObjects(baseDir: URL, projectBuildDir: URL, type: CObjectType, context: borrowing Beaver) async throws -> [URL] {
    //await self.persistedStorage.store(value: [URL:URL](), key: .objects) // to store in `objectFile` --> initialize once per artifact, this also means artifacts can't be built in parallell
    let cflags = (try await self.publicCflags())
      + (try await self.privateCflags(context: context))
      + (try await self.publicHeaders(baseDir: baseDir)).map { "-I\($0.path)"}
      + (try await self.privateHeaders(baseDir: baseDir, context: context)).map { "-I\($0.path)" }
    let objectBuildDir = self.objectBuildDir(projectBuildDir: projectBuildDir)
    let contextPtr = withUnsafePointer(to: context) { $0 }
    return try await self.loopSources(baseDir: baseDir) { source in
      return try await self.buildObject(baseDir: baseDir, buildDir: objectBuildDir, file: source, cflags: cflags, type: type, context: contextPtr.pointee)
    }
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

  /// TODO: support c++ -- switch on language
  public func executeCC(_ args: [String]) async throws {
    if let extraArgs = Tools.ccExtraArgs {
      try await Tools.exec(Tools.cc!, extraArgs + args)
    } else {
      try await Tools.exec(Tools.cc!, args)
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

  func collectSources(baseDir: borrowing URL) async throws -> [URL] {
    try await self._sources.files(baseURL: baseDir).reduce(into: [URL](), { $0.append($1) })
  // TODO: rework
  //  if let sources: [URL] = try await self.persistedStorage.getElement(withKey: .sources) {
  //    return sources
  //  } else {
  //    let sources: [URL] = try await self._sources.files(baseURL: baseDir).reduce(into: [URL](), { $0.append($1) })
  //    await self.persistedStorage.store(value: sources, key: .sources)
  //    return sources
  //  }
  }
}
