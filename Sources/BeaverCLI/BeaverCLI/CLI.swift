import Foundation
import Beaver
import BeaverRuby
import CLIPackage
import Utils

// TODO: softSetup?

@main
@Cli
struct BeaverCLI: Sendable {
  static let filenames = ["beaver", "Beaverfile", "beaver.rb", "beaver.build", "make.rb", "build.rb"]

  @Argument(
    name: "file",
    shortName: "f",
    help: "The path to your script file",
    default: {
      return Self.filenames
        .first(where: { filename in
          FileManager.default.fileExists(atPath: filename)
        })
        .map { URL(filePath: $0) }
    }
  )
  var file: URL? = nil

  @Argument(name: "opt", shortName: "o")
  var optimizationMode: OptimizationMode = .debug

  @Flag(name: "version", shortName: "v")
  var version: Bool = false

  static func main() async {
    do {
      let args = ProcessInfo.processInfo.arguments.dropFirst()
      var cli = try self.init(arguments: args)
      try await cli.run()
    } catch {
      print("\(error)", to: .stderr)
      exit(1)
    }
  }

  func validate() throws(ValidationError) {}

  func getScriptFile() throws -> URL {
    if let file = self.file {
      if FileManager.default.fileExists(atPath: file.path) {
        return URL(filePath: file.path)
      } else {
        throw ValidationError("Script file \(file.path) doesn't exist")
      }
    } else {
      throw ValidationError("No script file found. Create a file name with a name that matches \(Self.filenames[0..<(Self.filenames.count-1)].joined(separator: ", ")) or \(Self.filenames[Self.filenames.count - 1]), or specify a custom filename using the '-f' flag.")
    }
  }

  mutating func run() async throws {
    let commandName = self.takeArgument() ?? "build"

    if self.version {
      self.printVersion()
      return
    }

    switch (commandName) {
      case "build":
        try await self.build()
      case "clean":
        try await self.clean()
      default:
        fatalError("unknown command \(commandName)")
    }
  }

  func printVersion() {
    print("Beaver version: 1.0.0")
    print("Ruby version: \(rubyVersionDescription())")
  }

  func parseScript() async throws -> Beaver {
    let scriptFile = try self.getScriptFile()

    let rcCtx = Rc(try Beaver())

    do {
      // TODO: passing arguments
      let queue = try executeRuby(
        scriptFile: scriptFile,
        context: UnsafeSendable(rcCtx)
      )
      try await queue.wait()
      //deinitRuby()
    } catch let error as RbError {
      let description = error.description
      //deinitRuby()
      throw ExecutionError(description)
    } catch let error {
      //if rubyInit { deinitRuby() }
      throw error
    }

    return rcCtx.take()!
  }

  mutating func build() async throws {
    //try initRuby()

    let target = self.takeArgument()

    //var context = rcCtx.take()!
    var context = try await self.parseScript()
    try context.finalize()

    print(await context.debugString)

    if let target = target {
      try await context.build(targetName: target)
    } else {
      try await context.buildCurrentProject()
    }
  }

  mutating func clean() async throws {
    var context = try await self.parseScript()
    try context.finalize()

    try await context.clean()
  }
}

struct ExecutionError: Error, CustomStringConvertible {
  let message: String

  init(_ message: String) {
    self.message = message
  }

  var description: String {
    self.message
  }
}
