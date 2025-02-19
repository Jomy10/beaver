import Beaver

extension BeaverCLI {
  mutating func clean(context: borrowing Beaver) async throws {
    try await context.clean()
  }
}
