import Foundation
import Utils

struct NinjaRunner {
  let buildFile: String
  let ninja: URL
  let verbose: Bool

  init(buildFile: String, verbose: Bool = false) throws {
    self.buildFile = buildFile
    self.ninja = try Tools.requireNinja
    self.verbose = verbose
  }

  @usableFromInline
  func run(tool: String) async throws {
    try await Tools.execSilent(self.ninja, ["-f", self.buildFile, "-t", tool])
  }

  @available(*, deprecated)
  @usableFromInline
  func runSync(tool: String) throws {
    try Tools.execSilentSync(self.ninja, ["-f", self.buildFile, "-t", tool])
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
