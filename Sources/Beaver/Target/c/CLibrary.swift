import Foundation
import Utils

public struct CLibrary: CTarget, Library, ~Copyable {
  public let name: String
  public var description: String?
  public var homepage: URL?
  public var version: Version?
  public var license: String?
  public var language: Language

  public var id: Int = -1
  public var projectId: ProjectRef = -1

  public var artifacts: [LibraryArtifactType]
  public var dependencies: [Dependency]

  public var sources: Files
  public var headers: Headers
  public var extraCFlags: Flags
  public var extraLinkerFlags: [String]

  public static let defaultArtifacts: [LibraryArtifactType] = [.dynlib, .staticlib, .pkgconfig]

  // TODO: necessary?
  //public var storage: AsyncRWLock<Storage> = AsyncRWLock(Storage())

  public init(
    name: String,
    description: String? = nil,
    version: Version? = nil,
    homepage: URL? = nil,
    license: String? = nil,
    language: Language = .c,
    artifacts: [LibraryArtifactType] = Self.defaultArtifacts,
    sources: Files = Files(),
    headers: Headers = Headers(),
    cflags: Flags = Flags(),
    linkerFlags: [String],
    dependencies: [Dependency] = []
  ) throws {
    self.name = name
    self.description = description
    self.homepage = homepage
    self.version = version
    self.license = license
    self.language = language
    self.sources = sources
    self.headers = headers
    self.extraCFlags = cflags
    self.extraLinkerFlags = linkerFlags
    self.artifacts = artifacts
    self.dependencies = dependencies

    if !Self.allowedLanguages.contains(self.language) {
      throw TargetValidationError(self, .invalidLanguage(self.language))
    }
  }

  static let allowedLanguages: [Language] = [.c, .cxx, .objc, .objcxx]

  static let staticExt: String = ".a"
  #if canImport(Darwin)
  static let dynamicExt: String = ".dylib"
  #elseif os(Windows)
  static let dynamicExt: String = ".dll"
  #else
  static let dynamicExt: String = ".so"
  #endif

  public func artifactURL(projectBuildDir: borrowing URL, artifact: LibraryArtifactType) -> URL? {
    guard let base = self.artifactOutputDir(projectBuildDir: projectBuildDir, artifact: artifact) else {
      return nil
    }
    switch (artifact) {
      case .dynlib:
        return base.appending(path: "lib\(self.name)\(Self.dynamicExt)")
      case .staticlib:
        return base.appending(path: "lib\(self.name)\(Self.staticExt)")
      case .pkgconfig:
        return base.appending(path: "lib\(self.name).pc")
      default:
        return nil
    }
  }

  public func build(
    artifact: LibraryArtifactType,
    projectBaseDir: borrowing URL,
    projectBuildDir: borrowing URL,
    context: borrowing Beaver
  ) async throws {
    let artifactExists = FileManager.default.exists(at: self.artifactURL(projectBuildDir: projectBuildDir, artifact: artifact)!)
    switch (artifact) {
      case .dynlib:
        #if os(Windows)
        try await self.build(artifact: .staticlib, projectBaseDir: projectBaseDir, buildDir: projectBuildDir, context: context)
        fatalError("unimplemented")
        #else
        let (objects, rebuild) = try await self.buildObjects(projectBaseDir: projectBaseDir, projectBuildDir: projectBuildDir, artifact: artifact, context: context)

        let (depLinkerFlags, relink) = try await self.dependencyLinkerFlagsAndRelink(context: context, forBuildingArtifact: artifact)

        if rebuild || !artifactExists || relink {
          try await self.buildDynamicLibrary(
            objects: objects,
            dependencyLinkerFlags: depLinkerFlags,
            projectBaseDir: projectBaseDir,
            projectBuildDir: projectBuildDir,
            context: context
          )
        }
        #endif
      case .staticlib:
        let (objects, rebuild) = try await self.buildObjects(projectBaseDir: projectBaseDir, projectBuildDir: projectBuildDir, artifact: artifact, context: context)
        if rebuild || !artifactExists {
          try self.buildStaticLibrary(objects: objects, projectBaseDir: projectBaseDir, projectBuildDir: projectBuildDir, context: context)
        }
      case .pkgconfig:
        fatalError("Unimplemented artifact: \(artifact)")
      case .framework:
        fatalError("Unimplemented artifact: \(artifact)")
      case .xcframework:
        fatalError("Unimplemented artifact: \(artifact)")
      case .dynamiclanglib(_): fallthrough
      case .staticlanglib(_):
        throw TargetValidationError(self, .unsupportedArtifact(artifact.asArtifactType()))
    }
  }

  public func linkAgainstLibrary(projectBuildDir: borrowing URL, artifact: LibraryArtifactType) -> [String] {
    switch (artifact) {
      case .dynlib:
        return ["-L\(self.artifactOutputDir(projectBuildDir: projectBuildDir, artifact: artifact)!.path)", "-l\(self.name)"]
      case .staticlib:
        return [self.artifactURL(projectBuildDir: projectBuildDir, artifact: artifact)!.path]
      case .framework:
        return ["-F\(self.artifactOutputDir(projectBuildDir: projectBuildDir, artifact: artifact)!.path)", "-framework", self.name]
      case .xcframework:
        fatalError("todo")
      case .pkgconfig:
        fatalError("Can't link against pkgconfig (bug)")
      case .staticlanglib(_): fallthrough
      case .dynamiclanglib(_):
        fatalError("Found incompatible artifact for \(Self.self) (bug)")
    }
  }

  func buildDynamicLibrary(
    objects objectFiles: borrowing [URL],
    dependencyLinkerFlags depLinkerFlags: [String],
    projectBaseDir: borrowing URL,
    projectBuildDir: borrowing URL,
    context: borrowing Beaver
  ) async throws {
    let buildBaseDir = self.artifactOutputDir(projectBuildDir: projectBuildDir, artifact: .dynlib)!
    try FileManager.default.createDirectoryIfNotExists(at: buildBaseDir, withIntermediateDirectories: true)

    let outputFile = self.artifactURL(projectBuildDir: projectBuildDir, artifact: .dynlib)!

    var args: [String]
    #if os(macOS)
    args = ["-dynamiclib"]
    #elseif os(Windows)
    if !Platform.minGW {
      MessageHandler.print("[WARN] not running in minGW on platform Windows (unimplemented)")
    }
    args = ["-shared", "-Wl,--out-implib,\(try await self.artifactURL(projectBuildDir: projectBuildDir, .staticlib).path)"]
    #else
    args = ["-shared"]
    #endif

    //var depLinkerFlags: [String] = []
    //var depLanguages: Set<Language> = []
    //let contextPtr = withUnsafePointer(to: context) { $0 }
    //try await self.loopUniqueDependenciesRecursive(context: context) { (dependency: Dependency) in
    //  depLinkerFlags.append(contentsOf: try await dependency.linkerFlagsAndArtifactURL(context: contextPtr.pointee, collectingLanguageIn: &depLanguages))
    //}

    args.append(contentsOf: ["-o", outputFile.path]
      + objectFiles.map { $0.path }
      + depLinkerFlags
      //+ depLanguages.compactFlatMap { $0.linkerFlags(targetLanguage: self.language) }
    )

    try self.executeCC(args)
  }

  func buildStaticLibrary(objects: borrowing [URL], projectBaseDir: borrowing URL, projectBuildDir: borrowing URL, context: borrowing Beaver) throws {
    let buildBaseDir = self.artifactOutputDir(projectBuildDir: projectBuildDir, artifact: .staticlib)!
    try FileManager.default.createDirectoryIfNotExists(at: buildBaseDir, withIntermediateDirectories: true)

    let outputFile = self.artifactURL(projectBuildDir: projectBuildDir, artifact: .staticlib)!
    try Tools.exec(Tools.ar!, ["-rc", outputFile.path] + objects.map { $0.path }, context: self.name)
  }
}
