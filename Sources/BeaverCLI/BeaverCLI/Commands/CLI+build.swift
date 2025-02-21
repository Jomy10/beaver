import Beaver

extension BeaverCLI {
  mutating func build(context: Beaver) async throws {
    if let target = self.takeArgument() {
      try await context.build(targetName: target)
    } else {
      try await context.buildCurrentProject()
    }
  }
}
