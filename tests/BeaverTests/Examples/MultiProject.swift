import Testing
import Foundation
import Darwin
import Utils
@testable import Beaver

@Test func exampleMultiProject() async throws {
  let baseURL = URL(filePath: "Examples/MultiProject", relativeTo: URL.currentDirectory())
  print(baseURL)

  try await Tools.exec(beaverExeURL, ["clean"], baseDir: baseURL)
  try await Tools.exec(beaverExeURL, ["build", "Main", "-o", optMode], baseDir: baseURL)
  let outputExeURL = baseURL.appending(path: "build/MainProject/\(optMode)/artifacts/Main")
  #expect(FileManager.default.exists(at: outputExeURL))

  let (stdout, _) = try Tools.execWithOutput(outputExeURL, [], baseDir: baseURL)
  let lines = stdout.split(whereSeparator: \.isNewline)
  #expect(lines.count == 2)
  #expect(lines[0] == "cmp = 0")
  #expect(lines[1] == "buffer = [INFO] Hello world")
}
