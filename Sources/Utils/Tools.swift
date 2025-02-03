import Foundation
import Platform
import ColorizeSwift
import Atomics

public struct Tools {
  @inlinable
  public static func which(_ cmdName: String) -> URL? {
    let env = ProcessInfo.processInfo.environment
    let exts = env["PATHEXT"] != nil ? env["PATHEXT"]!.split(separator: ";") : [""]
    if let paths = env["PATH"]?.split(separator: PATH_LIST_SEPARATOR) {
      for path in paths {
        let pathURL = URL(fileURLWithPath: String(path))
        for ext in exts {
          let exeURL = pathURL.appendingPathComponent("\(cmdName)\(ext)")
          if FileManager.default.isExecutableFile(atPath: exeURL.path) && !FileManager.default.isDirectory(exeURL) {
            return exeURL
          }
        }
      }
    }
    return nil
  }

  static func findTool(name: String, envName: String? = nil, aliases: [String]? = nil) -> URL? {
    if let envName = envName {
      if let tool = ProcessInfo.processInfo.environment[envName] {
        let toolURL = URL(fileURLWithPath: tool)
        if !FileManager.default.isExecutableFile(atPath: toolURL.path) {
          MessageHandler.warn("Environment variable \"\(envName)\" exists, but doesn't point to a valid executable")
        } else if FileManager.default.isDirectory(toolURL) {
          MessageHandler.warn("Environment variable \"\(envName)\" exists, but points to a directory")
        } else {
          return toolURL
        }
      }
    }

    if let aliases = aliases {
      for cmdName in ([name] + aliases) {
        if let tool = Tools.which(cmdName) {
          return tool
        }
      }
      return nil
    } else {
      return Tools.which(name)
    }
  }

  public struct ProcessError: Error {
    public let terminationStatus: Int32
    public let reason: Process.TerminationReason

    @usableFromInline
    internal init(terminationStatus: Int32, reason: Process.TerminationReason) {
      self.terminationStatus = terminationStatus
      self.reason = reason
    }
  }

  public struct ExecutionError: Error {
    public let stderr: String
  }

  // TODO: replace with `execWithOutput`
  private static func _exec(_ cmdURL: URL, _ args: [String]) throws {
    let task = Process()
    let stderrPipe = Pipe()
    task.standardError = stderrPipe
    task.executableURL = cmdURL
    task.arguments = args
    task.environment = ProcessInfo.processInfo.environment
    try task.run()
    task.waitUntilExit()

    if task.terminationStatus != 0 {
      throw ExecutionError(stderr: String(data: stderrPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? "<error reading stderr>")
    }
  }

  /// Execute a command and return the output to stderr/stdout as a string
  @inlinable
  public static func execWithOutput(_ cmdURL: URL, _ args: [String], baseDir: URL = URL.currentDirectory()) throws -> (stderr: String, stdout: String) {
    let task = Process()
    let stderrPipe = Pipe()
    let stdoutPipe = Pipe()
    task.standardError = stderrPipe
    task.standardOutput = stdoutPipe
    task.executableURL = cmdURL
    task.arguments = args
    task.currentDirectoryURL = baseDir
    task.environment = ProcessInfo.processInfo.environment

    try task.run()
    task.waitUntilExit()

    if task.terminationStatus != 0 {
      throw ProcessError(terminationStatus: task.terminationStatus, reason: task.terminationReason)
    }

    let stdout = if let data = try stdoutPipe.fileHandleForReading.readToEnd() { String(data: data, encoding: .utf8)! } else { String() }
    let stderr = if let data = try stderrPipe.fileHandleForReading.readToEnd() { String(data: data, encoding: .utf8)! } else { String() }

    return (stdout, stderr)
  }

  /// Execute a command without output and return the exit code
  @inlinable
  public static func execWithExitCode(_ cmdURL: URL, _ args: [String], baseDir: URL = URL.currentDirectory()) throws -> Int {
    let task = Process()
    task.executableURL = cmdURL
    task.arguments = args
    task.currentDirectoryURL = baseDir
    task.environment = ProcessInfo.processInfo.environment

    try task.run()
    task.waitUntilExit()

    return Int(task.terminationStatus)
  }

  /// Outputs data received by a pipe, line by line, where each line is prefixed by a prefix string
  @usableFromInline
  final class PipeOutputter: Sendable {
    let pipe: Pipe
    let outputStream: IOStream
    let context: MessageHandler.MessageVisibility
    let prefix: String

    @usableFromInline
    init(pipe: Pipe, outputStream: IOStream, context: MessageHandler.MessageVisibility, prefix: String) {
      self.pipe = pipe
      self.outputStream = outputStream
      self.context = context
      self.prefix = prefix
    }

    @usableFromInline
    func spawn() -> Task<(), any Error> {
      // TODO: priority -> when compiling lower, when running, higher
      Task { [self = self] in
        var bytes: [UInt8] = []
        let newLine = Character("\n").asciiValue!
        for try await byte in pipe.fileHandleForReading.bytes {
          bytes.append(byte)
          if byte == newLine {
            let data = bytes.withUnsafeMutableBufferPointer { data in
              Data(
                bytesNoCopy: UnsafeMutableRawPointer(data.baseAddress!),
                count: data.count,
                deallocator: .none
              )
            }
            let string = String(data: data, encoding: .utf8)!
            //let str = if let prefix = self.prefix { prefix + string } else { string }
            MessageHandler.print(self.prefix + string, to: self.outputStream, context: self.context, terminator: "")
            bytes.removeAll(keepingCapacity: true)
            //MessageHandler.print(String(bytes))
          }
        } // end for

        if bytes.count > 0 {
          let data = bytes.withUnsafeMutableBufferPointer { data in
            Data(
              bytesNoCopy: UnsafeMutableRawPointer(data.baseAddress!),
              count: data.count,
              deallocator: .none
            )
          }
          let string = String(data: data, encoding: .utf8)!
          for string in string.split(whereSeparator: \.isNewline) {
            MessageHandler.print(self.prefix + string, to: self.outputStream, context: self.context, terminator: bytes.last == newLine ? "" : "\n")
          }
        }
      }
    }
  }

  /// Output to stderr/stdout with a prefix before each line of `[context]`
  @inlinable
  public static func exec(_ cmdURL: URL, _ args: [String], baseDir: URL = URL.currentDirectory(), context: String) async throws {
    let contextString: String = "[\(context)] "
    let task = Process()
    let stderrPipe = Pipe()
    let stderrOut = PipeOutputter(pipe: stderrPipe, outputStream: .stderr, context: .shellOutputStderr, prefix: contextString)
    let stdoutPipe = Pipe()
    let stdoutOut = PipeOutputter(pipe: stdoutPipe, outputStream: .stdout, context: .shellOutputStdout, prefix: contextString)

    task.standardError = stderrPipe
    task.standardOutput = stdoutPipe
    task.executableURL = cmdURL
    task.arguments = args
    task.currentDirectoryURL = baseDir
    task.environment = ProcessInfo.processInfo.environment
    //let stderrTask = stderrQueue.start()
    //let stdoutTask = stdoutQueue.start()
    MessageHandler.print(((cmdURL.path + " " + args.joined(separator: " ")).prependingIfNeeded(contextString)).darkGray(), to: .stderr, context: .shellCommand)
    let stderrTask = stderrOut.spawn()
    let stdoutTask = stdoutOut.spawn()
    try task.run()
    //for try await val in stderrPipe.fileHandleForReading.bytes.characters {
    //  MessageHandler.print("\(val)", to: .stderr, context: .shellOutputStderr, terminator: "")
    //}

    _ = try await stderrTask.value
    _ = try await stdoutTask.value
    task.waitUntilExit()

    if task.terminationStatus != 0 {
      throw ProcessError(terminationStatus: task.terminationStatus, reason: task.terminationReason)
    }
  }

  /// Output immediately to stderr/stdout
  @inlinable
  public static func exec(_ cmdURL: URL, _ args: [String], baseDir: URL = URL.currentDirectory()) async throws {
    let task = Process()

    task.standardError = FileHandle.standardError
    task.standardOutput = FileHandle.standardOutput
    task.executableURL = cmdURL
    task.arguments = args
    task.currentDirectoryURL = baseDir
    task.environment = ProcessInfo.processInfo.environment

    MessageHandler.print((cmdURL.path + " " + args.joined(separator: " ")).darkGray(), to: .stderr, context: .shellCommand)

    try task.run()

    task.waitUntilExit()

    if task.terminationStatus != 0 {
      throw ProcessError(terminationStatus: task.terminationStatus, reason: task.terminationReason)
    }
  }

  /// Statics are lazy variables
  public static let cc: URL? = Tools.findTool(name: "cc", envName: "CC", aliases: ["clang", "gcc", "zig", "icc"])
  public static let ccExtraArgs: [String]? = {
    if Self.cc?.lastPathComponent.split(separator: ".").first == "zig" {
      return ["cc"]
    } else {
      return nil
    }
  }()

  public static let cxx: URL? = Tools.findTool(name: "cxx", envName: "CXX", aliases: ["clang++", "g++", "zig", "icpc"])
  public static let cxxExtraArgs: [String]? = {
    if Self.cxx?.lastPathComponent.split(separator: ".").first == "zig" {
      return ["c++"]
    } else {
      return nil
    }
  }()

  #if os(macOS)
  public static let objcCompiler: URL? = Tools.findTool(name: "clang")
  #else
  public static let objcCompiler: URL? = Tools.findTool(name: "gcc")
  #endif

  public static let gnustepConfig: URL? = Tools.findTool(name: "gnustep-config")
  #if os(macOS)
  public static let objcCflags: [String] = ["-x", "objective-c"]
  #else
  public static let objcCflags: [String] = try! Tools._exec(Tools.gnustepConfig!, ["--objc-flags"])
  #endif

  #if os(macOS)
  public static let objcxxCflags: [String] = ["-x", "objective-c++"]
  #else
  public static let objcxxCflags: [String] = Tools.objcCflags
  #endif

  #if os(macOS)
  public static let objcLinkerFlags: [String] = ["-framework", "Foundation"]
  #else
  public static let objcLinkerFlags: [String] = try! Tools._exec(Tools.gnustepConfig!, ["--objc-libs", "--base-libs"])
  #endif

  public static let lipo: URL? = Tools.findTool(name: "lipo")

  public static let ar: URL? = Tools.findTool(name: "ar", envName: "AR")

  public static let pkgconfig: URL? = Tools.findTool(name: "pkgconf", envName: "PKG_CONFIG", aliases: ["pkg-config", "pkgconfig"])

  public static let sh: URL? = Tools.findTool(name: "sh", aliases: ["zsh", "bash", "fish"])

  public static let cmake: URL? = Tools.findTool(name: "cmake")

  public static let make: URL? = Tools.findTool(name: "make")

  /// String to argument string
  @inlinable
  public static func parseArgs(_ input: String) -> [Substring] {
    var output: [Substring] = []
    var startIndex: String.Index = input.startIndex
    var currentIndex: String.Index = input.startIndex
    var searchingForNewWord = false
    var openedString = false
    var escape = false
    while currentIndex < input.endIndex {
      if escape {
        currentIndex = input.index(after: currentIndex)
        escape = false
        continue
      }
      switch (input[currentIndex]) {
        case " ":
          if !searchingForNewWord {
            output.append(input[startIndex..<currentIndex])
          }
          searchingForNewWord = true
          startIndex = input.index(after: currentIndex)
        case "\"":
          openedString.toggle()
        case "\\":
          escape = true
        default:
          searchingForNewWord = false
      }
      currentIndex = input.index(after: currentIndex)
    }
    output.append(input[startIndex..<input.endIndex])
    return output
  }
}

extension Process.TerminationReason: @retroactive CustomStringConvertible {
  public var description: String {
    switch (self) {
      case .exit: "normal exit"
      case .uncaughtSignal: "uncaught signal"
      default: "unknown termination reason"
    }
  }
}
