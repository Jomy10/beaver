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
    linkerFlags: [String] = [],
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

  /// All linker flags, including dependency linker flags
  func linkerFlags(forArtifact artifactType: ArtifactType, context: borrowing Beaver) async throws -> [String] {
    var flags = [String]()
    if artifactType == .dynlib {
      #if os(macOS)
      flags.append("-dynamiclib")
      #elseif os(Windows)
      fatalError("unimplemented: Windows")
      #else
      flags.append("-shared")
      #endif
    }
    return flags
      + (try await self.dependencyLinkerFlags(context: context))
      + self.extraLinkerFlags
  }


  public func buildStatements<P: Project & ~Copyable>(inProject project: borrowing P, context: borrowing Beaver) async throws -> BuildBackendBuilder {
    let sources = try await self.collectSources(projectBaseDir: project.baseDir)
    let projectBuildDir = context.buildDir(for: project.name)
    let objectBuildDir = self.objectBuildDir(projectBuildDir: projectBuildDir)

    if sources.count == 0 {
      MessageHandler.warn("Target \(project.name):\(self.name) has no sources")
    }
    let cflags = try await self.cflags(projectBaseDir: project.baseDir, context: context)
        .map { "\"\($0)\"" }
        .joined(separator: " ")

    var stmts = BuildBackendBuilder()

    for artifact in self.artifacts {
      let artifactFile = self.artifactURL(projectBuildDir: projectBuildDir, artifact: artifact)!.ninjaPath
      switch (artifact) {
        case .staticlib:
          stmts.add("# Build \(project.name):\(self.name) artifact \(artifact)")
          var objectFiles = [String]()
          for source in sources {
            let objectFile = self.objectFile(
              projectBaseDir: project.baseDir,
              objectBuildDir: objectBuildDir,
              sourceFile: source,
              type: .static
            )
            let objectFilePath = objectFile.ninjaPath
            objectFiles.append(objectFilePath)
            stmts.addBuildCommand(
              in: [source.ninjaPath],
              out: objectFilePath,
              rule: self.ccRule,
              flags: ["cflags": cflags]
            )
          }
          stmts.addBuildCommand(
            in: objectFiles,
            out: artifactFile,
            rule: "ar"
          )
        case .dynlib:
          stmts.add("# Build \(project.name):\(self.name) artifact \(artifact)")
          var objectFiles = [String]()
          for source in sources {
            let objectFile = self.objectFile(
              projectBaseDir: project.baseDir,
              objectBuildDir: objectBuildDir,
              sourceFile: source,
              type: .dynamic
            )

            let objectFilePath = objectFile.ninjaPath
            objectFiles.append(objectFilePath)
            stmts.addBuildCommand(
              in: [source.ninjaPath],
              out: objectFilePath,
              rule: self.ccRule,
              flags: ["cflags": "-fPIC " + cflags]
            )
          }
          stmts.addBuildCommand(
            in: objectFiles,
            out: artifactFile,
            rule: "link",
            flags: ["linkerFlags": try await self.linkerFlags(forArtifact: artifact, context: context).map { "\"\($0)\"" }.joined(separator: " ")]
          )
        default:
          fatalError("unimplemented artifact \(artifact)")
      }
      stmts.addPhonyCommand(
        name: "\(project.name)$:\(self.name)$:\(artifact)",
        command: artifactFile
      )
    } // end for artifacts

    stmts.addPhonyCommand(
      name: "\(project.name)$:\(self.name)",
      commands: self.artifacts.map { artifact in "\(project.name)$:\(self.name)$:\(artifact)" }
    )

    return stmts
  }

  //public func build(
  //  artifact: LibraryArtifactType,
  //  projectBaseDir: borrowing URL,
  //  projectBuildDir: borrowing URL,
  //  context: borrowing Beaver
  //) async throws {
  //  let artifactURL = self.artifactURL(projectBuildDir: projectBuildDir, artifact: artifact)!
  //  let artifactExists = FileManager.default.exists(at: artifactURL)
  //  switch (artifact) {
  //    case .dynlib:
  //      #if os(Windows)
  //      try await self.build(artifact: .staticlib, projectBaseDir: projectBaseDir, buildDir: projectBuildDir, context: context)
  //      fatalError("unimplemented")
  //      #else
  //      let (objects, objectsRebuilt) = try await self.buildObjects(projectBaseDir: projectBaseDir, projectBuildDir: projectBuildDir, artifact: artifact, context: context)

  //      let outputFile = self.artifactURL(projectBuildDir: projectBuildDir, artifact: .dynlib)!
  //      let depLinkerFlags = try await self.dependencyLinkerFlags(context: context, forBuildingArtifact: outputfile, ofType: artifact.asArtifactType())
  //      //let forceRelink = try context.fileCache!.shouldRelinkArtifact(target: self.ref, artifact: artifact.asArtifactType(), artifactFile: artifactURL)
  //      let relinkArtifact = try context.fileCache!.shouldRebuild(target: self.ref, artifact: artifact.asArtifactType(), file: artifactURL)

  //      if objectsRebuilt || !artifactExists || relinkArtifact {
  //        try await self.buildDynamicLibrary(
  //          objects: objects,
  //          dependencyLinkerFlags: depLinkerFlags,
  //          outputFile: outputFile,
  //          projectBaseDir: projectBaseDir,
  //          projectBuildDir: projectBuildDir,
  //          context: context
  //        )
  //      }
  //      #endif
  //    case .staticlib:
  //      let (objects, rebuild) = try await self.buildObjects(projectBaseDir: projectBaseDir, projectBuildDir: projectBuildDir, artifact: artifact, context: context)
  //      if rebuild || !artifactExists {
  //        try await self.buildStaticLibrary(objects: objects, projectBaseDir: projectBaseDir, projectBuildDir: projectBuildDir, context: context)
  //      }
  //    case .pkgconfig:
  //      fatalError("Unimplemented artifact: \(artifact)")
  //    case .framework:
  //      fatalError("Unimplemented artifact: \(artifact)")
  //    case .xcframework:
  //      fatalError("Unimplemented artifact: \(artifact)")
  //    case .dynamiclanglib(_): fallthrough
  //    case .staticlanglib(_):
  //      throw TargetValidationError(self, .unsupportedArtifact(artifact.asArtifactType()))
  //  }
  //}

  public func linkAgainstLibrary(projectBuildDir: borrowing URL, artifact: LibraryArtifactType) -> [String] {
    self.linkAgainstArtifact(projectBuildDir: projectBuildDir, artifact: artifact)
  }

  @available(*, deprecated)
  func buildDynamicLibrary(
    objects objectFiles: borrowing [URL],
    dependencyLinkerFlags depLinkerFlags: [String],
    outputFile: URL,
    projectBaseDir: borrowing URL,
    projectBuildDir: borrowing URL,
    context: borrowing Beaver
  ) async throws {
    let buildBaseDir = self.artifactOutputDir(projectBuildDir: projectBuildDir, artifact: .dynlib)!
    try FileManager.default.createDirectoryIfNotExists(at: buildBaseDir, withIntermediateDirectories: true)

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
      + self.extraLinkerFlags
      //+ depLanguages.compactFlatMap { $0.linkerFlags(targetLanguage: self.language) }
    )

    try await self.executeCC(args)
  }

  @available(*, deprecated)
  func buildStaticLibrary(objects: borrowing [URL], projectBaseDir: borrowing URL, projectBuildDir: borrowing URL, context: borrowing Beaver) async throws {
    let buildBaseDir = self.artifactOutputDir(projectBuildDir: projectBuildDir, artifact: .staticlib)!
    try FileManager.default.createDirectoryIfNotExists(at: buildBaseDir, withIntermediateDirectories: true)

    let outputFile = self.artifactURL(projectBuildDir: projectBuildDir, artifact: .staticlib)!
    try await Tools.exec(Tools.ar!, ["-rc", outputFile.path] + objects.map { $0.path }, context: self.name)
  }
}
