import Beaver

extension BeaverCLI {
  func clean(context: borrowing Beaver) async throws {
    try await context.clean()
  }
}
