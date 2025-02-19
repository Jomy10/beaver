fileprivate extension String {
  mutating func appendLine(_ val: String) {
    self.append(val)
    self.append("\n")
  }
}

//private actor MutableString {
//  var storage = String()

//  @inlinable
//  func appendLine(_ str: String) {
//    self.storage.appendLine(str)
//  }

//  @inlinable
//  func mutating(_ cb: (inout String) -> Void) {
//    cb(&self.storage)
//  }
//}

///// ninja backened
//struct SharedBuildBackendBuilder: Sendable {
//  private let buildFile = MutableString()

//  func addRule(name: String, _ values: [String: String]) async {
//    await self.buildFile.mutating { str in
//      str.appendLine("rule \(name)")
//      str.appendLine(values.map { k, v in "    \(k) = \(v)" }.joined(separator: "\n"))
//    }
//  }

//  func addBuildCommand(in input: [String], out output: String, rule: String, flags: [String]) async {
//    await self.buildFile.mutating { str in
//      str.appendLine("build \(output): \(rule) \(input.joined(separator: " "))")
//      for flag in flags {
//        str.appendLine("    \(flag)")
//      }
//    }
//  }

//  func addBuildCommend(in input: [String], out output: String, rule: String, flags: [String: String]) async {
//    await self.addBuildCommand(in: input, out: output, rule: rule, flags: flags.map { k, v in "\(k) = \(v)" })
//  }

//  func add(_ arbitrary: String) async {
//    await self.buildFile.appendLine(arbitrary)
//  }

//  func join(_ other: consuming SharedBuildBackendBuilder) async {
//    await self.buildFile.appendLine(await other.buildFile.storage)
//  }

//  func join(_ other: consuming BuildBackendBuilder) async {
//    await self.buildFile.appendLine(other.storage)
//  }
//}

/// ninja backend
public struct BuildBackendBuilder: Sendable, ~Copyable {
  fileprivate var storage = String()

  mutating func addRule(name: String, _ values: [String: String]) {
    self.storage.appendLine("rule \(name)")
    self.storage.appendLine(values.map { k, v in "    \(k) = \(v)" }.joined(separator: "\n"))
  }

  mutating func addBuildCommand(in input: [String], out output: String, rule: String, flags: [String] = []) {
    self.storage.appendLine("build \(output): \(rule) \(input.joined(separator: " "))")
    for flag in flags {
      self.storage.appendLine("    \(flag)")
    }
  }

  mutating func addBuildCommand(in input: [String], out output: String, rule: String, flags: [String: String]) {
    self.addBuildCommand(in: input, out: output, rule: rule, flags: flags.map { k, v in "\(k) = \(v)" })
  }

  mutating func addPhonyCommand(name: String, commands: [String]) {
    self.storage.appendLine("build \(name): phony \(commands.joined(separator: " "))")
  }

  mutating func addPhonyCommand(name: String, command: String) {
    self.storage.appendLine("build \(name): phony \(command)")
  }

  mutating func add(_ arbitrary: String) {
    self.storage.appendLine(arbitrary)
  }

  mutating func join(_ other: consuming BuildBackendBuilder) {
    self.storage.appendLine(other.storage)
  }

  consuming func finalize() -> String {
    return self.storage
  }
}
