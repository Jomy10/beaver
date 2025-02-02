import Foundation
import Utils

public struct CExecutable: CTarget, Executable, ~Copyable {
  public let name: String
  public var description: String?
  public var homepage: URL?
  public var version: Version?
  public var license: String?
  public var language: Language

  public var id: Int = -1
  public var projectId: ProjectRef = -1

  public var artifacts: [ExecutableArtifactType]
  public var dependencies: [Dependency]

  public var sources: Files
  public var headers: Headers
  public var extraCFlags: Flags
  public var extraLinkerFlags: [String]

  public static let defaultArtifacts: [ExecutableArtifactType] = [.executable]

  // TODO: necessary?
  //public var storage: AsyncRWLock<Storage> = AsyncRWLock(Storage())

  public init(
    name: String,
    description: String? = nil,
    version: Version? = nil,
    homepage: URL? = nil,
    license: String? = nil,
    language: Language = .c,
    artifacts: [ExecutableArtifactType] = Self.defaultArtifacts,
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

  #if os(Windows)
  static let exeExt: String = ".exe"
  #else
  static let exeExt: String = ""
  #endif

  public func artifactURL(projectBuildDir: borrowing URL, artifact: ExecutableArtifactType) -> URL? {
    guard let base = self.artifactOutputDir(projectBuildDir: projectBuildDir, artifact: artifact) else {
      return nil
    }

    switch (artifact) {
      case .executable:
        return base.appending(path: "\(self.name)\(Self.exeExt)")
      case .app:
        return base.appending(path: "\(self.name).app")
    }
  }

  public func build(
    artifact: ExecutableArtifactType,
    projectBaseDir: borrowing URL,
    projectBuildDir: borrowing URL,
    context: borrowing Beaver
  ) async throws {
    let artifactURL = self.artifactURL(projectBuildDir: projectBuildDir, artifact: artifact)!
    let artifactExists = FileManager.default.exists(at: artifactURL)
    let (objects, rebuilt) = try await self.buildObjects(projectBaseDir: projectBaseDir, projectBuildDir: projectBuildDir, artifact: artifact, context: context)
    if artifact == .app {
      fatalError("unimplemented")
    }
    let (depLinkerFlags, relink) = try await self.dependencyLinkerFlagsAndRelink(context: context, forBuildingArtifact: artifact)
    let forceRelink = try context.fileCache!.shouldRelinkArtifact(target: self.ref, artifact: artifact.asArtifactType(), artifactFile: artifactURL)
    if rebuilt || !artifactExists || relink || forceRelink {
      try await self.buildExecutable(
        objects: objects,
        dependencyLinkerFlags: depLinkerFlags,
        projectBaseDir: projectBaseDir,
        projectBuildDir: projectBuildDir,
        context: context
      )
    }
  }

  /// Link all objects and dependencies
  func buildExecutable(
    objects: borrowing [URL],
    dependencyLinkerFlags depLinkerFlags: [String],
    projectBaseDir: borrowing URL,
    projectBuildDir: borrowing URL,
    context: borrowing Beaver
  ) async throws {
    let buildBaseDir = self.artifactOutputDir(projectBuildDir: projectBuildDir, artifact: .executable)!
    try FileManager.default.createDirectoryIfNotExists(at: buildBaseDir)
    let outputFile = self.artifactURL(projectBuildDir: projectBuildDir, artifact: .executable)!

    //var depLinkerFlags: [String] = []
    //var depLanguages: Set<Language> = []
    //let contextPtr = withUnsafePointer(to: context) { $0 }
    //try await self.loopUniqueDependenciesRecursive(context: context) { (dependency: Dependency) in
    //  depLinkerFlags.append(contentsOf: try await dependency.linkerFlags(context: contextPtr.pointee, collectingLanguageIn: &depLanguages))
    //}

    let args: [String] = objects.map { $0.path }
      + depLinkerFlags
      + self.extraLinkerFlags
      //+ depLanguages.compactFlatMap { $0.linkerFlags(targetLanguage: self.language) }
      + ["-o", outputFile.path]
    try await self.executeCC(args)
  }
}
