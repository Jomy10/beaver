import Foundation
import Platform

public struct CLibrary: CTarget, Library {
  public var id: Int = -1
  public let name: String
  public var description: String?
  public var version: Version?
  public var homepage: URL?
  public var language: Language
  public var artifacts: [LibraryArtifactType]
  public var dependencies: [Dependency]

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

    language: Language = .c,

    artifacts: [LibraryArtifactType] = [.dynlib, .staticlib, .pkgconfig],

    // C
    sources: Files,
    headers: Headers = Headers(),
    cflags: Flags = Flags(),
    linkerFlags: [String] = [],

    dependencies: [Dependency] = []
  ) throws(InvalidLanguage) {
    self.name = name
    self.description = description
    self.version = version
    self.homepage = homepage
    self.language = language
    self.artifacts = artifacts
    self.dependencies = dependencies
    self._sources = sources
    self.headers = headers
    self.extraCflags = cflags
    self.extraLinkerFlags = linkerFlags

    if !Array<Language>([.c, .cxx, .objc, .objcxx]).contains(language) {
      throw InvalidLanguage(language: language)
    }
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

  public func build(
    artifact: LibraryArtifactType,
    baseDir: borrowing URL,
    buildDir projectBuildDir: borrowing URL,
    context: borrowing Beaver
  ) async throws {
    switch (artifact) {
      case .dynlib:
        #if os(Windows)
        try await self.build(artifact: .staticlib, baseDir: baseDir, buildDir: projectBuildDir, context: context)
        #endif
        let objects = try await self.buildObjects(baseDir: baseDir, projectBuildDir: projectBuildDir, type: .dynamic, context: context)
        try await self.buildDynamicLibrary(objects: objects, baseDir: baseDir, projectBuildDir: projectBuildDir, context: context)
      case .staticlib:
        let objects = try await self.buildObjects(baseDir: baseDir, projectBuildDir: projectBuildDir, type: .static, context: context)
        try await self.buildStaticLibrary(objects: objects, baseDir: baseDir, projectBuildDir: projectBuildDir, context: context)
      case .pkgconfig:
        await MessageHandler.warn("Unimplemented artifact: \(artifact)")
      case .framework:
        await MessageHandler.warn("Unimplemented artifact: \(artifact)")
      case .xcframework:
        await MessageHandler.warn("Unimplemented artifact: \(artifact)")
      case .dynamiclanglib(_): fallthrough
      case .staticlanglib(_):
        throw BuildError.unsupportedArtifact
    }
  }

  private func buildDynamicLibrary(objects objectFiles: borrowing [URL], baseDir: URL, projectBuildDir: URL, context: borrowing Beaver) async throws {
    //let sources = try await self.collectSources(baseDir: baseDir)
    let buildBaseDir = try await self.artifactOutputDir(projectBuildDir: projectBuildDir, forArtifact: .dynlib)
    if !buildBaseDir.exists {
      try FileManager.default.createDirectory(at: buildBaseDir, withIntermediateDirectories: true)
    }
    //let objectBuildDir = self.objectBuildDir(projectBuildDir: projectBuildDir)
    //let objectFiles = await sources.async.map({ source in await self.objectFile(baseDir: baseDir, buildDir: objectBuildDir, file: source, type: .dynamic )}).map { $0.path }.reduce(into: [String](), { $0.append($1) })
    let outputFile = try await self.artifactURL(projectBuildDir: projectBuildDir, .dynlib)
    // TODO: append linker flags!!! --> linker flags of all dependencies (DependencyGraph!!)
    var args: [String]
    #if os(macOS)
    // -fvisibility=hidden -> explicityly export symbols (see https://developer.apple.com/library/archive/documentation/DeveloperTools/Conceptual/DynamicLibraries/100-Articles/CreatingDynamicLibraries.html)
    args = ["-dynamiclib"]
    #elseif os(Windows)
    if !Platform.minGW {
      MessageHandler.print("[WARN] not running in minGW on platform Windows (unip")
    }
    args = ["-shared", "-Wl,--out-implib,\(try await self.artifactURL(projectBuildDir: projectBuildDir, .staticlib).path)"]
    #else
    args = ["-shared"]
    #endif

    var visited: Set<Dependency> = Set()
    let aargs: [String] = ["-o", outputFile.path]
      + objectFiles.map { $0.path }
      + (try await self.allLinkerFlags(context: context, visited: &visited))
      + (try await self.languages(context: context).compactMap { lang in lang.linkerFlags(targetLanguage: self.language) }.flatMap { $0 })
    try await self.executeCC(args + aargs)
  }

  private func buildStaticLibrary(objects: borrowing [URL], baseDir: URL, projectBuildDir: URL, context: borrowing Beaver) async throws {
    //let sources = try await self.collectSources(baseDir: baseDir)
    //let buildBaseDir = buildDir.appendingPathComponent("artifacts")
    let buildBaseDir = try await self.artifactOutputDir(projectBuildDir: projectBuildDir, forArtifact: .staticlib)
    if !buildBaseDir.exists {
      try FileManager.default.createDirectory(at: buildBaseDir, withIntermediateDirectories: true)
    }
    let outputFile = try await self.artifactURL(projectBuildDir: projectBuildDir, .staticlib)
    //let objectBuildDir = self.objectBuildDir(projectBuildDir: projectBuildDir)
    try await Tools.exec(
      Tools.ar!,
      ["-rc", outputFile.path] + objects.map { $0.path }
    )
  }

  /// Flags for linking agains this library. Does not include any of the dependencies' libraries
  public func linkerFlags() async throws -> [String] {
    self.extraLinkerFlags + ["-l\(self.name)"]
  }
}
