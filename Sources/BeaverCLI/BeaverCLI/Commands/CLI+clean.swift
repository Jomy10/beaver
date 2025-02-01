import Beaver

extension BeaverCLI {
  mutating func clean(context: borrowing Beaver) async throws {
    if let projectName = self.takeArgument() {
      try await context.clean(projectName: projectName)
    } else {
      try await context.clean()
    }
  }
}
