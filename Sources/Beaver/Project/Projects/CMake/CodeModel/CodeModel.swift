/// CodeModel v2
struct CMakeCodeModelV2: Codable {
  let kind: String
  let version: CMakeObjectVersion
  let paths: CMakePaths
  let configurations: [CMakeConfiguration]
}
