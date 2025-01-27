struct CMakeCommandFragment: Codable {
  /// Encoded in the native shell format
  let fragment: String
  /// A string specifying the role of the fragment's content:
  /// - flags: link flags.
  /// - libraries: link library file paths or flags.
  /// - libraryPath: library search path flags.
  /// - frameworkPath: macOS framework search path flags.
  let role: String?
}
