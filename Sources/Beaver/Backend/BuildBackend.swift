fileprivate extension String {
  mutating func appendLine(_ val: String) {
    self.append(val)
    self.append("\n")
  }
}

/// ninja backend
public struct BuildBackendBuilder: Sendable, ~Copyable {
  fileprivate var storage = String()

  mutating func addRule(name: String, _ values: [String: String]) {
    self.storage.appendLine("rule \(name)")
    self.storage.appendLine(values.map { k, v in "    \(k) = \(v)" }.joined(separator: "\n"))
  }

  mutating func addRules(forLanguages languages: Set<Language>) throws {
    var rules: Set<NinjaRule> = Set()
    for language in languages {
      try language.ninjaRules(into: &rules)
    }
    for rule in rules {
      self.addRule(name: rule.name, rule.values)
    }
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
