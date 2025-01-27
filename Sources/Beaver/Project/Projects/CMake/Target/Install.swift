struct CMakeInstall: Codable {
  let prefix: CMakePrefix
  let destinations: [CMakeDestination]
}

struct CMakePrefix: Codable {
  let path: String
}

struct CMakeDestination: Codable {
  let path: String
  let backtrace: UInt
}
