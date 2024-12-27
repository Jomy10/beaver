import Foundation
import Platform

public struct CLibrary: CTarget, Library {
  public let name: String
  public var description: String?
  public var version: Version?
  public var homepage: URL?
  public var language: Language
  public var artifacts: [LibraryArtifactType]
  public var dependencies: [LibraryRef]

  var persistedStorage = try! PersistedStorage<CTargetStorageKey>()
  var _sources: Files
  var headers: Headers
  var extraCflags: Flags
  var extraLinkerFlags: [String]

  public init(
    // Info //
    name: String,
    description: String? = nil,
    version: Version? = nil,
    homepage: URL? = nil,

    artifacts: [LibraryArtifactType] = [.dynlib, .staticlib, .pkgconfig],

    // C
    sources: Files,
    headers: Headers = Headers(),
    cflags: Flags = Flags(),
    linkerFlags: [String] = [],

    dependencies: [LibraryRef] = []
  ) {
    self.name = name
    self.description = description
    self.version = version
    self.homepage = homepage
    self.language = .c
    self.artifacts = artifacts
    self.dependencies = dependencies
    self._sources = sources
    self.headers = headers
    self.extraCflags = cflags
    self.extraLinkerFlags = linkerFlags
  }

  static let staticExt: String = ".a"
  #if canImport(Darwin)
  static let dynamicExt: String = ".dylib"
  #elseif os(Windows)
  static let dynamicExt: String = ".dll"
  #else
  static let dynamicExt: String = ".so"
  #endif

  public func artifactURL(projectBuildDir: URL, _ artifact: LibraryArtifactType) async throws -> URL {
    let base = try await self.artifactOutputDir(projectBuildDir: projectBuildDir, forArtifact: artifact)
    switch (artifact) {
      case .dynlib:
        return base.appending(path: "lib\(self.name)\(Self.dynamicExt)")
      case .staticlib:
        return base.appending(path: "lib\(self.name)\(Self.staticExt)")
      case .pkgconfig:
        return base.appending(path: "lib\(self.name).pc")
      default:
        throw UnsupportedArtifact(artifact)
    }
  }

  enum BuildError: Error {
    case unsupportedArtifact
  }

  //public func artifactOutputDir(projectBuildDir: URL, forArtifact artifact: LibraryArtifactType?) async throws -> URL {
  //  projectBuildDir.appending(path: self.name).appending(path: "artifacts")
  //}

  public func build(artifact: LibraryArtifactType, baseDir: borrowing URL, buildDir projectBuildDir: borrowing URL, context: borrowing Beaver) async throws {
    switch (artifact) {
      case .dynlib:
        #if os(Windows)
        try await self.buildObjects(baseDir: baseDir, projectBuildDir: projectBuildDir, type: .static, context: context)
        try await self.buildStaticLibrary(baseDir: baseDir, projectBuildDir: projectBuildDir, context: context)
        #endif
        try await self.buildObjects(baseDir: baseDir, projectBuildDir: projectBuildDir, type: .dynamic, context: context)
        try await self.buildDynamicLibrary(baseDir: baseDir, projectBuildDir: projectBuildDir, context: context)
      case .staticlib:
        try await self.buildObjects(baseDir: baseDir, projectBuildDir: projectBuildDir, type: .static, context: context)
        try await self.buildStaticLibrary(baseDir: baseDir, projectBuildDir: projectBuildDir, context: context)
      case .pkgconfig:
        break
      case .dynamiclanglib(_): fallthrough
      case .staticlanglib(_):
        throw BuildError.unsupportedArtifact
    }
  }

  private func buildDynamicLibrary(baseDir: URL, projectBuildDir: URL, context: borrowing Beaver) async throws {
    let sources = try await self.collectSources(baseDir: baseDir)
    let buildBaseDir = try await self.artifactOutputDir(projectBuildDir: projectBuildDir, forArtifact: .dynlib)
    if !buildBaseDir.exists {
      try FileManager.default.createDirectory(at: buildBaseDir, withIntermediateDirectories: true)
    }
    let objectBuildDir = self.objectBuildDir(projectBuildDir: projectBuildDir)
    let objectFiles = await sources.async.map({ source in await self.objectFile(baseDir: baseDir, buildDir: objectBuildDir, file: source, type: .dynamic )}).map { $0.path }.reduce(into: [String](), { $0.append($1) })
    let outputFile = try await self.artifactURL(projectBuildDir: projectBuildDir, .dynlib)
    #if os(macOS)
    // -fvisibility=hidden -> explicityly export symbols (see https://developer.apple.com/library/archive/documentation/DeveloperTools/Conceptual/DynamicLibraries/100-Articles/CreatingDynamicLibraries.html)
    let args = ["-dynamiclib", "-o", outputFile.path] + objectFiles
    #elseif os(Windows)
    if !Platform.minGW {
      print("[WARN] not running in minGW on platform Windows")
    }
    let args = ["-shared", "-o", outputFile.path, "-Wl,--out-implib,\(try await self.artifactURL(projectBuildDir: projectBuildDir, .staticlib).path)"] + objectFiles
    #else
    let args = ["-shared", "-o", outputFile.path] + objectFiles
    #endif
    if let extraArgs = Tools.ccExtraArgs {
      try await Tools.exec(
        Tools.cc!,
        extraArgs + args
      )
    } else {
      try await Tools.exec(
        Tools.cc!,
        args
      )
    }
  }

  private func buildStaticLibrary(baseDir: URL, projectBuildDir: URL, context: borrowing Beaver) async throws {
    let sources = try await self.collectSources(baseDir: baseDir)
    //let buildBaseDir = buildDir.appendingPathComponent("artifacts")
    let buildBaseDir = try await self.artifactOutputDir(projectBuildDir: projectBuildDir, forArtifact: .staticlib)
    if !buildBaseDir.exists {
      try FileManager.default.createDirectory(at: buildBaseDir, withIntermediateDirectories: true)
    }
    let outputFile = try await self.artifactURL(projectBuildDir: projectBuildDir, .staticlib)
    let objectBuildDir = self.objectBuildDir(projectBuildDir: projectBuildDir)
    try await Tools.exec(
      Tools.ar!,
      ["-rc", outputFile.path] + (await sources.async.map({ source in await self.objectFile(baseDir: baseDir, buildDir: objectBuildDir, file: source, type: .static) }).map { $0.path }.reduce(into: [String](), { $0.append($1) }))
    )
  }

  public func linkerFlags() async throws -> [String] {
    self.extraLinkerFlags + ["-l\(self.name)"]
  }
}
