import Foundation

public struct CExecutable: CTarget, Executable {
  public let name: String
  public var description: String?
  public var version: Version?
  public var homepage: URL?
  public var language: Language
  public var artifacts: [ExecutableArtifactType]
  public var dependencies: [LibraryRef]

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
    artifacts: [ExecutableArtifactType] = [.executable],

    sources: Files,
    headers: Headers = Headers(public: nil, private: nil),
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
    self.persistedStorage = try! PersistedStorage()
    self._sources = sources
    self.headers = headers
    self.extraCflags = cflags
    self.extraLinkerFlags = linkerFlags
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
    switch (artifact) {
      case .executable:
        try await self.buildObjects(baseDir: baseDir, projectBuildDir: projectBuildDir, type: .static, context: context)
        try await self.buildExecutable(baseDir: baseDir, projectBuildDir: projectBuildDir, context: context)
      case .app:
        fatalError("unimplemented")
    }
  }

  func buildExecutable(baseDir: URL, projectBuildDir: URL, context: borrowing Beaver) async throws {
    let sources = try await self.collectSources(baseDir: baseDir)
    let buildBaseDir = try await self.artifactOutputDir(projectBuildDir: projectBuildDir, forArtifact: .executable)
    if !buildBaseDir.exists {
      try FileManager.default.createDirectory(at: buildBaseDir, withIntermediateDirectories: true)
    }
    let outputFile = try await self.artifactURL(projectBuildDir: projectBuildDir, .executable)

    var dependenciesLinkerFlags: [String] = []
    var libraryLinkPaths: Set<URL> = Set()
    for dependency in self.dependencies {
      //dependenciesLinkerFlags.append(contentsOf: try await context.withLibrary(dependency) { lib in return try await lib.linkerFlags() })
      let (path, flags) = try await context.withLibrary(dependency) { lib in return (try await lib.artifactOutputDir(projectBuildDir: projectBuildDir, forArtifact: dependency.artifact), try await lib.linkerFlags()) }
      dependenciesLinkerFlags.append(contentsOf: flags)
      libraryLinkPaths.insert(path)
    }

    let objectBuildDir = self.objectBuildDir(projectBuildDir: projectBuildDir)
    let objectFiles = (await sources.async.map { (source: URL) in return await self.objectFile(baseDir: baseDir, buildDir: objectBuildDir, file: source, type: .static).path }.reduce(into: [String](), { $0.append($1) }))
    let args: [String] = objectFiles
      + libraryLinkPaths.map { "-L\($0.path)" }
      + dependenciesLinkerFlags
      + ["-o", outputFile.path]
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
}
