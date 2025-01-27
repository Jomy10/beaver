struct CMakeLauncher: Codable {
  let command: String
  let arguments: [String]?
  /// Possible values:
  /// - `emulator`: an emulator for the target platfrom when cross-compiling.
  /// - `test`: a start program for the execution of tests
  let type: String
}
