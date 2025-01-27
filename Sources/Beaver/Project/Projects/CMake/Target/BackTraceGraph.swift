/// "codemodel" version 2 "backtrace graph"
struct CMakeBacktraceGraph: Codable {
  let nodes: [CMakeBacktraceNode]
  let commands: [String]
  let files: [String]
}

struct CMakeBacktraceNode: Codable {
  let file: Int
  let line: Int?
  let command: Int?
  let parent: Int?
}
