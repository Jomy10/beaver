import Testing
import Foundation
import Darwin
import Utils
@testable import Beaver

@Test func exampleCMake() async throws {
  let baseURL = URL(filePath: "Examples/CMake", relativeTo: URL.currentDirectory())
  print(baseURL)

  try await Tools.exec(beaverExeURL, ["clean"], baseDir: baseURL)
  try await Tools.exec(beaverExeURL, ["build", "-o", optMode], baseDir: baseURL)
  let artifactURL = baseURL.appending(path: "build/MyFileFormat/\(optMode)/artifacts")
  let outputExeURL = artifactURL.appending(path: "MyFileFormat")
  #expect(FileManager.default.exists(at: outputExeURL))

  let (stdout, _) = try Tools.execWithOutput(outputExeURL, [], baseDir: baseURL)
  let lines = stdout.split(whereSeparator: \.isNewline)
  #expect(lines.count == 1)
  #expect(lines[0] == "Tests passed successfully!")
}
