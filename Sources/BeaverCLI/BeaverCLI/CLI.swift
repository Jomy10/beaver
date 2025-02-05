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

  var rubySetup = false

  static func main() async {
    var cli: BeaverCLI? = nil
    do {
      let args = ProcessInfo.processInfo.arguments.dropFirst()
      cli = try self.init(arguments: args)
      try await cli!.runCLI()
      //if cli!.rubySetup {
      //  await RubyQueue.global.join()
      //}
    } catch {
      print("error: \(error)", to: .stderr)
      if cli?.rubySetup == true {
      //await RubyQueue.global.join()
        // Ruby has been setup, so we clean it up again on the same thread it was
        // initialized from
        //try! RubyQueue.global.submit({
        await MainActor.run {
          do {
            try cleanupRuby()
          } catch let error {
            MessageHandler.error("Error cleaning up Ruby: \(error)")
          }
        }
      }
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

  func runScript<C: Collection & BidirectionalCollection & Sendable>(args: C) async throws -> (UnsafeSendable<Rc<Beaver>>, SyncTaskQueue)
  where C.Element == String
  {
    let scriptFile = try self.getScriptFile()

    let rcCtx = UnsafeSendable(Rc(try Beaver(
      enableColor: self.color,
      optimizeMode: self.optimizationMode
    )))

    let queue: SyncTaskQueue
    do {
      // Ruby code has to be executed on the same thread!
      //queue = try await RubyQueue.global.submitSync {
      queue = try await MainActor.run {
        try executeRuby(
          scriptFile: scriptFile,
          args: args,
          context: rcCtx
        )
      }
      try await queue.wait() // Wait for method calls from ruby to finish setting up the context
    } catch let error as RbError {
      //let description = try await RubyQueue.global.submitSync {
      let description = await MainActor.run {
        error.errorDescription
      }
      throw ExecutionError(description)
    } catch let error {
      throw error
    }

    return (rcCtx, queue)
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
    if commandName == "init" {
      try self.initializeBeaver()
      return
    }

    if self.version {
      self.printVersion()
      return
    }

    if self.help {
      self.printHelp()
      return
    }

    let (args, leftover) = self.getArguments()

    //let __selfPtr = withUnsafeMutablePointer(to: &self) { $0 }
    //try await RubyQueue.global.submitSync {
    await MainActor.run {
      setupRuby()
      self.rubySetup = true
    }

    let (context, queue) = try await self.runScript(args: leftover)
    try await context.value.withInner { (context: inout Beaver) in
      try await context.finalize()
    }
    queue.resume() // allow cmd to call swift functions
    //MessageHandler.debug(await context.customDebugString(withSources: false, withDependencies: true))

    try await context.value.withInner { (context: borrowing Beaver) in
      if context.currentProjectIndex == nil {
        if let commandName = explicitCommand {
          try await context.call(commandName)
        } else {
          try await context.callDefault()
          // No project and no command specified (warn)
        }
      } else {
        if try await context.isOverwritten(commandName) {
          try await context.call(commandName)
        } else {
          switch (commandName) {
            case "build":
              try await self.build(context: context)
            case "clean":
              try await self.clean(context: context)
            case "run":
              try await self.run(args: args, context: context)
            case "list":
              try await self.list(context: context)
            default:
              try await context.call(commandName)
          }
        }
      }
    }

    //if self.rubySetup {
    //  await RubyQueue.global.join()
    //  self.rubySetup = false
    //}
    try await queue.wait()
  }

  func printVersion() {
    print("Beaver version: 1.0.0")
    print("Ruby version: \(rubyVersionDescription())")
  }

  static func valueForArgument<C: Collection & RangeRemovableCollection & BidirectionalCollection>(
    _ names: [String],
    in args: inout C
  ) throws -> String?
  where C.Element == String
  {
    if let index = names.firstValue(where: { args.firstIndex(of: $0) }) {
      if let valueIndex = args.index(index, offsetBy: 1, limitedBy: args.endIndex) {
        args.removeSubrange(index..<(args.index(index, offsetBy: 2, limitedBy: args.endIndex) ?? args.endIndex))
        return args[valueIndex]
      } else {
        throw ArgumentError("No value specified for \(names.first!)")
      }
    } else {
      return nil
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

struct ArgumentError: Error, CustomStringConvertible {
  let message: String

  init(_ message: String) {
    self.message = message
  }

  var description: String {
    self.message
  }
}
