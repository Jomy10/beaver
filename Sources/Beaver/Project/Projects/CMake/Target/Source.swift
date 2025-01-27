struct CMakeSource: Codable {
  /// A path to the source file on disk
  let path: String
  let compileGroupIndex: UInt?
  let sourceGroupIndex: UInt?
  let isGenerated: Bool?
  let fileSetIndex: UInt?
  let backtrace: UInt
}
