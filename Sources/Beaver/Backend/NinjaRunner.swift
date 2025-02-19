import Foundation
import Utils

struct NinjaRunner {
  let buildFile: String
  let ninja: URL
  let verbose: Bool = true // TODO

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
    var args = ["-f", self.buildFile] + targets
    if verbose { args.append("-v") }
    try await Tools.execSilent(self.ninja, args)
  }

  @usableFromInline
  func build(targets: [String]) async throws {
    var args = ["-f", self.buildFile] + targets
    if verbose { args.append("-v") }
    try await Tools.execSilent(self.ninja, args)
  }

  @usableFromInline
  func build(targets: String..., dir: String) async throws {
    var args = ["-C", dir, "-f", self.buildFile] + targets
    if verbose { args.append("-v") }
    try await Tools.execSilent(self.ninja, args)
  }
}
