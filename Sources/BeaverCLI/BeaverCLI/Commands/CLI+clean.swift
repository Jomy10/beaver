import Beaver

extension BeaverCLI {
  mutating func clean(context: Beaver) async throws {
    try await context.clean()
  }
}
