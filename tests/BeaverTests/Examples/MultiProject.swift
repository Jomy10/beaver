import Testing
import Foundation
import Darwin
import Utils
@testable import Beaver

@Test func exampleMultiProject() async throws {
  let baseURL = URL(filePath: "Examples/MultiProject", relativeTo: URL.currentDirectory())

  try await Tools.exec(beaverExeURL, ["build", "Main", "-o", optMode], baseDir: baseURL)
  defer { _ = try! Tools.execWithOutput(beaverExeURL, ["clean"], baseDir: baseURL) }
  let outputExeURL = baseURL.appending(path: ".build/\(optMode)/artifacts/Main")
  #expect(outputExeURL.exists)

  let (stdout, _) = try Tools.execWithOutput(outputExeURL, [], baseDir: baseURL)
  let lines = stdout.split(whereSeparator: \.isNewline)
  #expect(lines.count == 2)
  #expect(lines[0] == "cmp = 0")
  #expect(lines[1] == "buffer = [INFO] Hello world")
}
