// "codemodel" version 2 "target" object
struct CMakeTargetV2: Codable {
  let name: String
  let id: String
  /// `EXECUTABLE`, `STATIC_LIBRARY`, `SHARED_LIBRARY`, `MODULE_LIBRARY`,
  /// `OBJECT_LIBRARY`, `INTERFACE_LIBRARY` or `UTILITY`
  let type: String
  let backtrace: UInt?
  let folder: CMakeFolder?
  let paths: CMakePaths
  /// Present for executable and library targets that are linked or archived
  /// into a single primary artifact.
  let nameOnDisk: String?
  /// Present for executable and library targets that produce artifacts on disk
  /// meant for consumption by dependents.
  let artifacts: [CMakeArtifact]?
  let isGeneratorProvided: Bool?
  /// Present when the target has an `install()` rule
  let install: CMakeInstall?
  let launchers: CMakeLauncher?
  let link: CMakeLink?
  /// Present for static library targets
  let archive: CMakeArchive?
  let dependencies: [CMakeDependency]?
  /// Present in codemodel 2.5
  let fileSets: [CMakeFileSet]?
  let sources: [CMakeSource]
  let sourceGroups: [CMakeSourceGroup]?
  /// Present when the target has sources that compile
  let compileGroups: [CMakeCompileGroup]?
  let backtraceGraph: CMakeBacktraceGraph
}

struct CMakeArtifact: Codable {
  /// A string specifiying the file on disk, represented with forward slashes.
  /// Relative to the top-level build directory, or an absolute path
  let path: String
}

struct CMakeFolder: Codable {
  let name: String
}

struct CMakeFileSet: Codable {
  let name: String
  let type: String
  /// `PUBLIC`, `PRIVATE`, `INTERFACE`
  let visibility: String
  let baseDirectories: [String]
}
