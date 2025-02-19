import Foundation

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

  mutating func addNinjaRule() {
    self.addRule(name: "ninja", [
      "command": "ninja -C $ninjaBaseDir -f $ninjaFile $targets"
    ])
  }

  mutating func addBuildCommand(in input: [String], out output: String, rule: String, flags: [String] = [], dependencies: [String] = []) {
    var line = "build \(output): \(rule) \(input.joined(separator: " "))"
    if dependencies.count > 0 {
      line += " || \(dependencies.joined(separator: " "))"
    }
    self.storage.appendLine(line)
    for flag in flags {
      self.storage.appendLine("    \(flag)")
    }
  }

  mutating func addBuildCommand(in input: [String], out output: String, rule: String, flags: [String: String], dependencies: [String] = []) {
    self.addBuildCommand(in: input, out: output, rule: rule, flags: flags.map { k, v in "\(k) = \(v)" }, dependencies: dependencies)
  }

  mutating func addNinjaCommand(
    name: String,
    baseDir: URL,
    filename: String,
    targets: [String]?
  ) {
    self.storage.appendLine("build \(name): ninja")
    self.storage.appendLine("    ninjaBaseDir = \"\(baseDir)\"")
    self.storage.appendLine("    ninjaFile = \"\(filename)\"")
    if let targets {
      self.storage.appendLine("    targets = \(targets.map { $0.replacing(" ", with: "$").replacing(":", with: "$") }.joined(separator: " "))")
    }
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
