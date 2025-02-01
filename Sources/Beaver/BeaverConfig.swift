struct BeaverConfig: Codable {
  var cmake: CMakeConfig = CMakeConfig()

  struct CMakeConfig: Codable {
    var flagsInclude: FlagIncludeConfig = FlagIncludeConfig()

    struct FlagIncludeConfig: Codable {
      var compileCommandFragments: Bool = false
      var defines: Bool = true
    }
  }
}
