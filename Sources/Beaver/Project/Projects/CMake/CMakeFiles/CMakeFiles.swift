/// The cmakeFiles object kind lists files used by CMake while configuring
/// and generating the build system. These include the CMakeLists.txt files
/// as well as included .cmake files.
struct CMakeFilesV1: Codable {
  let paths: CMakePaths
  let inputs: [CMakeInput]?
  let globsDependent: CMakeGlobDependent?
}

struct CMakeInput: Codable {
  let path: String
  let isGenerated: Bool?
  let isExternal: Bool?
  let isCMake: Bool?
}

struct CMakeGlobDependent: Codable {
  /// A string specifying the globbing expression
  let expression: String
  let recurse: Bool?
  let listDirectories: Bool?
  let followSymlinks: Bool?
  let relative: Bool?
  /// The paths matched by the glob expression
  let paths: [String]
}
