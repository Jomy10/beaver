import Foundation

public struct CExecutable: CTarget, Executable {
  public var id: Int = -1
  public var projectId: Int = -1
  public let name: String
  public var description: String?
  public var version: Version?
  public var homepage: URL?
  public var language: Language
  public var artifacts: [ExecutableArtifactType]
  public var dependencies: [Dependency]

  var persistedStorage: PersistedStorage<CTargetStorageKey>
  var _sources: Files
  var headers: Headers
  var extraCflags: Flags
  var extraLinkerFlags: [String]

  public init(
    name: String,
    description: String? = nil,
    version: Version? = nil,
    homepage: URL? = nil,

    language: Language = .c,

    artifacts: [ExecutableArtifactType] = [.executable],

    sources: Files,
    headers: Headers = Headers(),
    cflags: Flags = Flags(),
    linkerFlags: [String] = [],

    dependencies: [Dependency] = []
  ) throws {
    self.name = name
    self.description = description
    self.version = version
    self.homepage = homepage
    self.language = language
    self.artifacts = artifacts
    self.dependencies = dependencies
    self.persistedStorage = try PersistedStorage()
    self._sources = sources
    self.headers = headers
    self.extraCflags = cflags
    self.extraLinkerFlags = linkerFlags

    if !Array<Language>([.c, .cxx, .objc, .objcxx]).contains(language) {
      throw InvalidLanguage(language: language)
    }
  }

  #if os(Windows)
  static let exeExt: String = ".exe"
  #else
  static let exeExt: String = ""
  #endif

  public func artifactURL(projectBuildDir: URL, _ artifact: ExecutableArtifactType) async throws -> URL {
    let base = try await self.artifactOutputDir(projectBuildDir: projectBuildDir, forArtifact: artifact)
    switch (artifact) {
      case .executable:
        return base.appending(path: "\(self.name)\(Self.exeExt)")
      case .app:
        return base.appending(path: "\(self.name).app")
    }
  }

  public func build(artifact: ExecutableArtifactType, baseDir: borrowing URL, buildDir projectBuildDir: borrowing URL, context: borrowing Beaver) async throws {
    let (objects, rebuild) = try await self.buildObjects(baseDir: baseDir, projectBuildDir: projectBuildDir, artifact: artifact, context: context)
    if rebuild {
      try await self.buildExecutable(objects: objects, baseDir: baseDir, projectBuildDir: projectBuildDir, context: context)
    }
    if artifact == .app {
      fatalError("unimplemented")
    }
  }

  func buildExecutable(objects: borrowing [URL], baseDir: URL, projectBuildDir: URL, context: borrowing Beaver) async throws {
    //let sources = try await self.collectSources(baseDir: baseDir)
    let buildBaseDir = try await self.artifactOutputDir(projectBuildDir: projectBuildDir, forArtifact: .executable)
    if !buildBaseDir.exists {
      try FileManager.default.createDirectory(at: buildBaseDir, withIntermediateDirectories: true)
    }
    let outputFile = try await self.artifactURL(projectBuildDir: projectBuildDir, .executable)

    var visited: Set<Dependency> = Set()
    let dependenciesLinkerFlags: [String] = try await self.allLinkerFlags(context: context, visited: &visited)

    let dependencyLanguages = try await self.languages(context: context)
    let args: [String] = objects.map { $0.path }
      + dependenciesLinkerFlags
      + dependencyLanguages.compactMap { $0.linkerFlags(targetLanguage: self.language) }.flatMap { $0 }
      + ["-o", outputFile.path]
    try await self.executeCC(args)
  }
}
