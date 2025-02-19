import Foundation
import Utils

struct NinjaRunner {
  let buildFile: String

  @usableFromInline
  func run(tool: String) async throws {
    try await Tools.execSilent(Tools.ninja!, ["-f", self.buildFile, "-t", tool])
  }

  @usableFromInline
  func build(targets: String...) async throws {
    try await Tools.execSilent(Tools.ninja!, ["-f", self.buildFile] + targets)
  }

  @usableFromInline
  func build(targets: [String]) async throws {
    try await Tools.execSilent(Tools.ninja!, ["-f", self.buildFile] + targets)
  }
}
