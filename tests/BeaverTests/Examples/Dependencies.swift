import Testing
import Foundation
import Darwin
import Utils
@testable import Beaver

@Test func exampleDependencies() async throws {
  let baseURL = URL(filePath: "Examples/Dependencies", relativeTo: URL.currentDirectory())
  print(baseURL)

  try await Tools.exec(beaverExeURL, ["clean"], baseDir: baseURL)
  try await Tools.exec(beaverExeURL, ["build", "-o", optMode], baseDir: baseURL)
  let artifactURL = baseURL.appending(path: "build/MyProject/\(optMode)/artifacts")
  let outputExeURL = artifactURL.appending(path: "Main")
  #expect(FileManager.default.exists(at: outputExeURL))
  #expect(FileManager.default.exists(at: artifactURL.appending(path: "libMyMath.a")))
  #expect(FileManager.default.exists(at: artifactURL.appending(path: "libMyMath.dylib"))) // TODO: platform specific

  let (stdout, _) = try Tools.execWithOutput(outputExeURL, [], baseDir: baseURL)
  let lines = stdout.split(whereSeparator: \.isNewline)
  #expect(lines.count == 2)
  #expect(lines[0] == "3")
  #expect(lines[1] == "1")
}
