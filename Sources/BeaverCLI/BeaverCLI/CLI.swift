import Foundation
import Beaver
import BeaverRuby
import CLIPackage
import Utils
import RubyGateway

#if canImport(Darwin)
import Darwin
#elseif canImport(Glibc)
import Glibc
#elseif canImport(Musl)
import Musl
#elseif os(Windows)
import ucrt
#else
#warning("Need implementation for current platform to determine terminal size")
#endif

@Cli
@main
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

  @Argument(name: "opt", shortName: "c", help: "Optimization mode (`debug` or `release`) (default: `debug`)")
  var _optimizationMode: OptimizationMode = .debug

  @Flag(name: "optimize", shortName: "o", help: "Shorthand for `-c release`")
  var optimize: Bool? = nil

  @Flag(name: "color", help: "Enable color output (default: automatic)")
  var color: Bool? = nil

  @Flag(name: "version", shortName: "v", negatable: false, help: "Print the version of this tool and the used ruby version")
  var version: Bool = false

  @Flag(name: "help", shortName: "h", negatable: false, help: "Show this help message")
  var help: Bool = false

  var optimizationMode: OptimizationMode {
    switch (self.optimize) {
      case nil:
        return self._optimizationMode
      case .some(true):
        return .release
      case .some(false):
        return .debug
    }
  }

  static func main() async {
    do {
      let args = ProcessInfo.processInfo.arguments.dropFirst()
      var cli = try self.init(arguments: args)
      try await cli.runCLI()
    } catch {
      print("error: \(error)", to: .stderr)
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

  func runScript<C: Collection & BidirectionalCollection & Sendable>(args: C) async throws -> Beaver
  where C.Element == String
  {
    let scriptFile = try self.getScriptFile()

    let rcCtx = UnsafeSendable(Rc(try Beaver(
      enableColor: self.color,
      optimizeMode: self.optimizationMode
    )))

    do {
      // Ruby code has to be executed on the main thread!
      let queue = try await MainActor.run {
        // TODO: passing arguments
        try executeRuby(
          scriptFile: scriptFile,
          args: args,
          context: rcCtx
        )
      }
      try await queue.wait() // Wait for method calls from ruby to finish setting up the context
    } catch let error as RbError {
      let description = await MainActor.run {
        error.errorDescription
      }
      throw ExecutionError(description)
    } catch let error {
      throw error
    }

    return rcCtx.value.take()!
  }

  func getArguments() -> ([String], DiscontiguousSlice<ArraySlice<String>>.SubSequence) {
    // collect arguments after --
    if let argsIndex: DiscontiguousSlice<ArraySlice<String>>.Index = self.leftoverArguments.firstIndex(of: "--") {
      (
        Array(self.leftoverArguments[self.leftoverArguments.index(after: argsIndex)..<self.leftoverArguments.endIndex]),
        self.leftoverArguments[self.leftoverArguments.startIndex..<argsIndex]
      )
    } else {
      (
        [],
        self.leftoverArguments
      )
    }
  }

  mutating func runCLI() async throws {
    let explicitCommand = self.takeArgument()
    let commandName = explicitCommand ?? "build"

    if self.version {
      self.printVersion()
      return
    }

    if self.help {
      self.printHelp()
      return
    }

    let (args, leftover) = self.getArguments()

    //var commandOverwrites: Set<String> = Set()
    var context = try await self.runScript(args: leftover)
    try context.finalize()

    if context.currentProjectIndex == nil {
      if let commandName = explicitCommand {
        try await context.call(commandName)
      } else {
        try await context.callDefault()
        // No project and no command specified (warn)
      }
    } else {
      if await context.isOverwritten(commandName) {
        try await context.call(commandName)
      } else {
        switch (commandName) {
          case "build":
            try await self.build(context: context)
          case "clean":
            try await self.clean(context: context)
          case "run":
            try await self.run(args: args, context: context)
          default:
            try await context.call(commandName)
        }
      }
    }
  }

  func printVersion() {
    print("Beaver version: 1.0.0")
    print("Ruby version: \(rubyVersionDescription())")
  }

  func printHelp() {
    let terminalWidth: Int?
    #if canImport(Darwin) || canImport(Glibc) || canImport(Musl)
    var terminalSize: winsize? = winsize()
    if ioctl(STDOUT_FILENO, TIOCGWINSZ, &terminalSize) != 0 {
      terminalSize = nil
    }
    terminalWidth = if let cols = terminalSize?.ws_col { Int(cols) } else { nil }
    #elseif os(Windows)
    let csbi = CONSOLE_SCREEN_BUFFER_INFO()
    GetConsoleScreenBufferInfo(GetStdHandle(STD_OUTPUT_HANDLE), &csbi)
    terminalWidth = csbi.srWindow.Right - csbi.srWindow.Left + 1
    #else
    terminalWidth = nil
    #endif

    let commandName = URL(filePath: ProcessInfo.processInfo.arguments.first!).lastPathComponent

    print("""
    [USAGE] \(commandName) [command] [options]

    COMMANDS
    """)
    self.printHelpPart("build [target]", "Build a target", terminalWidth: terminalWidth)
    self.printHelpPart("run [target]", "Run a target. Pass arguments to your executable using \"-- [args...]\"", terminalWidth: terminalWidth)
    self.printHelpPart("clean", "Clean the build folder and cache", terminalWidth: terminalWidth)

    print("\nOPTIONS")
    for opt in Self._arguments {
      self.printHelpPart({
          var optPart = "--\(opt.negatable ? "[no-]" : "")\(opt.fullName)"
          if let shortName = opt.shortName {
            optPart += ", -\(shortName)"
          }
          if opt is ArgumentDecl {
            optPart += " <arg>"
          }
          optPart += " "
          return optPart
        }(),
        opt.help,
        terminalWidth: terminalWidth
      )
    }
  }

  func printHelpPart(_ part: String, _ message: String?, terminalWidth: Int?) {
    let messageStartIndex = if let terminalWidth = terminalWidth {
      if terminalWidth <= 30 { 0 } else { 21 }
    } else { 21 }
    let argPartPrefix = "  "
    let argPartPostfix = " "
    let argPartSize = part.count + argPartPrefix.count + argPartPostfix.count
    print(argPartPrefix + part + argPartPostfix, terminator: argPartSize > messageStartIndex || message == nil ? "\n" : "")
    if let message = message {
      let doPrint: (any StringProtocol, Int) -> () = { message, index in
        let prefix = if argPartSize > messageStartIndex || index > 0 {
          String(repeating: " ", count: messageStartIndex)
        } else {
          String(repeating: " ", count: messageStartIndex - argPartSize)
        }
        print(prefix + message)
      }
      if let terminalWidth = terminalWidth {
        let messageSize = terminalWidth - messageStartIndex
        var startIndex = message.startIndex
        var index = 0
        while startIndex < message.endIndex {
          let endIndex = message.index(startIndex, offsetBy: messageSize, limitedBy: message.endIndex) ?? message.endIndex
          doPrint(message[startIndex..<endIndex], index)
          startIndex = endIndex
          index += 1
        }
      } else {
        doPrint(message, 0)
      }
    }
  }

  mutating func build(context: borrowing Beaver) async throws {
    if let target = self.takeArgument() {
      try await context.build(targetName: target)
    } else {
      try await context.buildCurrentProject()
    }
  }

  func clean(context: borrowing Beaver) async throws {
    try await context.clean()
  }

  mutating func run(args: [String], context: borrowing Beaver) async throws {
    let target = self.takeArgument()

    if let target = target {
      try await context.run(targetName: target, args: args)
    } else {
      try await context.run(args: args)
    }
  }
}

extension RbError {
  var errorDescription: String {
    if case .rubyException(let exc) = self {
      exc.backtrace.joined(separator: "\n") + "\n" + exc.description
    } else {
      self.description
    }
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
