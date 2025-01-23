import Beaver

extension BeaverCLI {
  mutating func run(args: [String], context: borrowing Beaver) async throws {
    let target = self.takeArgument()

    if let target = target {
      try await context.run(targetName: target, args: args)
    } else {
      try await context.run(args: args)
    }
  }

}
