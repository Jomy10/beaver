import Testing
import Foundation
import Darwin
import Utils
@testable import Beaver

@Test func exampleCProject() async throws {
  let baseURL = URL(filePath: "Examples/CProject", relativeTo: URL.currentDirectory())

  try await Tools.exec(beaverExeURL, ["build"], baseDir: baseURL)
  defer { try! execOutput(beaverExeURL, ["clean"], baseDir: baseURL) }
  let outputExeURL = baseURL.appending(path: "out/debug/artifacts/HelloWorld")
  #expect(outputExeURL.exists)

  let (stdout, _) = try execOutput(outputExeURL, [], baseDir: baseURL)
  #expect(stdout == "Hello world\n")
}
