import Foundation
import Utils

struct NinjaRunner {
  let buildFile: String
  let ninja: URL

  init(buildFile: String) throws {
    self.buildFile = buildFile
    self.ninja = try Tools.requireNinja
  }

  @usableFromInline
  func run(tool: String) async throws {
    try await Tools.execSilent(self.ninja, ["-f", self.buildFile, "-t", tool])
  }

  @usableFromInline
  func build(targets: String...) async throws {
    try await Tools.execSilent(self.ninja, ["-f", self.buildFile] + targets)
  }

  @usableFromInline
  func build(targets: [String]) async throws {
    try await Tools.execSilent(self.ninja, ["-f", self.buildFile] + targets)
  }

  @usableFromInline
  func build(targets: String..., dir: String) async throws {
    try await Tools.execSilent(self.ninja, ["-C", dir, "-f", self.buildFile] + targets)
  }
}
