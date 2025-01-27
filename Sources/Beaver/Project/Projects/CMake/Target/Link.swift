/// Describes the link step
struct CMakeLink: Codable {
  /// A string specifying the language (e.g. C, CXX, Fortran) of the toolchain is used to
  /// invoke the linker.
  let language: String
  let commandFragments: [CMakeCommandFragment]
  let lto: Bool?
  let sysroot: CMakeSysroot?
}

struct CMakeSysroot: Codable {
  let path: String
}
