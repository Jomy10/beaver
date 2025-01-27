struct CMakeConfiguration: Codable {
  /// e.g. "Debug"
  let name: String
  /// An array of entries each corresponding to a build system directory whose source
  /// directory contains a CMakeLists.txt file. The first entry corresponds to the
  /// top-level directory
  let directories: [CMakeDirectory]
  let projects: [CMakeProjectDescriptor]
  let targets: [CMakeTargetDescriptor]
}

struct CMakeDirectory: Codable {
  let source: String
  let build: String
  /// Present when the directory has subdirectories
  let childIndexes: [Int]?
  /// Present when the directory is not top-level
  let parentIndex: Int?
  let projectIndex: Int
  let targetIndexes: [Int]?
  let minimumCMakeVersion: CMakeVersion?
  let hasInstallRule: Bool?
  /// Path to a "codemodelv2"."directory object". Available from codemodel version 2.3
  let jsonFile: String
}

struct CMakeVersion: Codable {
  /// A string specifying the minimum required version in the format:
  /// `<major>.<minor>[.<patch>[.<tweak>]][<suffix>]`
  /// Each component is an unsigned integer and the suffix may be an arbitrary string.
  let string: String
}

struct CMakeProjectDescriptor: Codable {
  let name: String
  let parentIndex: Int?
  let childIndexes: [Int]?
  let directoryIndexes: [Int]
  let targetIndexes: [Int]?
}

struct CMakeTargetDescriptor: Codable {
  let name: String
  let id: String
  let directoryIndex: Int
  let projectIndex: Int
  let jsonFile: String
}
