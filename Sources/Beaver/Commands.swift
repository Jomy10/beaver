public actor Commands {
  public typealias Command = @Sendable (borrowing Beaver) async throws -> ()

  var `default`: String? = nil
  var commands: [String: Command]
  /// Rather informative, only used by the cli
  var overwrites: Set<String>

  enum Error: Swift.Error {
    case commandExists(String)
    case commandDoesntExist(String)
    case noDefaultCommand
  }

  init() {
    self.commands = [:]
    self.overwrites = Set()
  }

  func addCommand(
    name: String,
    overwrite: Bool = false,
    execute: @escaping Command
  ) throws {
    if self.commands[name] != nil {
      throw Self.Error.commandExists(name)
    }
    self.commands[name] = execute

    if self.default == nil {
      self.default = name
    }
    if overwrite {
      self.overwrites.insert(name)
    }
  }

  func call(_ command: String, context: borrowing Beaver) async throws {
    guard let command = self.commands[command] else {
      throw Self.Error.commandDoesntExist(command)
    }

    try await command(context)
  }

  func callDefault(context: borrowing Beaver) async throws {
    guard let commandName = self.default else {
      throw Self.Error.noDefaultCommand
    }
    let command = self.commands[commandName]!

    try await command(context)
  }
}
