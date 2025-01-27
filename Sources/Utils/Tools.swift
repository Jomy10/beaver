import Foundation
import Platform
import ColorizeSwift

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

  @inlinable
  public static func exec(_ cmdURL: URL, _ args: [String], baseDir: URL = URL.currentDirectory(), context: String? = nil) throws {
    let task = Process()
    let stderrPipe = Pipe()
    let stdoutPipe = Pipe()
    let contextStr: String? = if let context = context { "[\(context)] " } else { nil }
    stderrPipe.fileHandleForReading.readabilityHandler = { handle in
      let data: Data = handle.availableData
      if data.count == 0 {
        handle.readabilityHandler = nil
        MessageHandler.flush(.stderr)
      } else {
        MessageHandler.print(String(data: data, encoding: .utf8)!.prependingRowsIfNeeded(contextStr), to: .stderr, context: .shellOutputStderr, terminator: "")
      }
    }
    stdoutPipe.fileHandleForReading.readabilityHandler = { handle in
      let data: Data = handle.availableData
      if data.count == 0 {
        handle.readabilityHandler = nil
        MessageHandler.flush(.stdout)
      } else {
        MessageHandler.print(String(data: data, encoding: .utf8)!.prependingRowsIfNeeded(contextStr), to: .stdout, context: .shellOutputStdout, terminator: "")
      }
    }

    task.standardError = stderrPipe
    task.standardOutput = stdoutPipe
    task.executableURL = cmdURL
    task.arguments = args
    task.currentDirectoryURL = baseDir
    task.environment = ProcessInfo.processInfo.environment
    MessageHandler.print(((cmdURL.path + " " + args.joined(separator: " ")).prependingIfNeeded(contextStr)).darkGray(), to: .stderr, context: .shellCommand)
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
