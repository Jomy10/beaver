import Testing
import Foundation
import Darwin
import Utils
@testable import Beaver

@Test func exampleCProject() async throws {
  let baseURL = URL(filePath: "Examples/CProject", relativeTo: URL.currentDirectory())

  try await Tools.exec(beaverExeURL, ["clean"], baseDir: baseURL)
  try await Tools.exec(beaverExeURL, ["build"], baseDir: baseURL)

  let outputExeURL = baseURL.appending(path: "build/MyProject/debug/artifacts/HelloWorld")
  #expect(FileManager.default.exists(at: outputExeURL))

  let (stdout, _) = try Tools.execWithOutput(outputExeURL, [], baseDir: baseURL)
  #expect(stdout == "Hello world\n")
}
