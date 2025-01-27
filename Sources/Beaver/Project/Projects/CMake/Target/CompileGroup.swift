struct CMakeCompileGroup: Codable {
  let sourceIndexes: [UInt]?
  let language: String
  let languageStandard: CMakeLanguageStandard?
  let compileCommandFragments: [CMakeCommandFragment]?
  let includes: [CMakeIncludePath]?
  let frameworks: [CMakeIncludePath]?
  let precompileHeaders: [CMakePrecompileHeader]?
  let defines: [CMakeDefine]?
  let sysroot: CMakeSysroot?
}

struct CMakeLanguageStandard: Codable {
  let backtraces: [UInt]?
  let standard: String
}

struct CMakeIncludePath: Codable {
  let path: String
  /// Wether this is a system include directory
  let isSystem: Bool?
  let backtrace: UInt?
}

struct CMakePrecompileHeader: Codable {
  let header: String
  let backtrace: UInt?
}

struct CMakeDefine: Codable {
  /// A string specifying the preprocessor definition in the format <name>[=<value>], e.g. DEF or DEF=1.
  let define: String
  let backtrace: UInt?
}
