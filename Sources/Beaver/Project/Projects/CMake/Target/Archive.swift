struct CMakeArchive: Codable {
  let commandFragments: [CMakeCommandFragment]?
  let lto: Bool?
}
