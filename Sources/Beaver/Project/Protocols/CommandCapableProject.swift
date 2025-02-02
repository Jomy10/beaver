/// A project for which custom commands can be registered
public protocol CommandCapableProject: ~Copyable, Project, Sendable {
  mutating func addCommand(
    _ name: String,
    overwrite: Bool,
    _ execute: @escaping Commands.Command
  ) async throws

  func call(_ commandName: String, context: borrowing Beaver) async throws

  func callDefault(context: borrowing Beaver) async throws

  func isOverwritten(_ commandName: String) async -> Bool

  func hasCommand(_ commandName: String) async -> Bool
  func hasCommands() async -> Bool
}
