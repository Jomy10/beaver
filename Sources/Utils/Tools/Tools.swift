import Foundation
import Platform
import Atomics

#if canImport(Darwin)
import Darwin
#elseif canImport(Glibc)
import Glibc
#elseif canImport(Musl)
import Musl
#elseif os(Windows)
import ucrt
#else
#warning("Need implementation for current platform to determine isatty")
#endif

fileprivate func __isatty(_ i: Int32) -> Int32 {
  #if os(Windows)
  _isatty(i)
  #else
  isatty(i)
  #endif
}

public struct Tools {
  private static nonisolated(unsafe) var _enableColor: Bool = (__isatty(fileno(stdout)) == 1 && __isatty(fileno(stderr)) == 1)
  public static nonisolated(unsafe) var enableColor: Bool {
    get {
      self._enableColor
    }
    set {
      self._enableColor = newValue
      MessageHandler.setColorEnabled(self._enableColor)
    }
  }

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

  public static func findTool(name: String, envName: String? = nil, aliases: [String]? = nil) -> URL? {
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

  public struct ToolValidationError: Error {
    let tool: String
  }

  private static func requireTool(_ url: URL?, name: String) throws -> URL {
    guard let toolURL = url else {
      throw ToolValidationError(tool: name)
    }
    return toolURL
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
  public static var requireCC: URL { get throws {
    try self.requireTool(Self.cc, name: "cc")
  }}

  public static let cxx: URL? = Tools.findTool(name: "cxx", envName: "CXX", aliases: ["clang++", "g++", "zig", "icpc"])
  public static let cxxExtraArgs: [String]? = {
    if Self.cxx?.lastPathComponent.split(separator: ".").first == "zig" {
      return ["c++"]
    } else {
      return nil
    }
  }()
  public static var requireCXX: URL { get throws {
    try self.requireTool(Self.cxx, name: "cxx")
  }}

  #if os(macOS)
  public static let objcCompiler: URL? = Tools.findTool(name: "clang")
  #else
  public static let objcCompiler: URL? = Tools.findTool(name: "gcc")
  #endif
  public static var requireObjCCompiler: URL { get throws {
    try self.requireTool(Self.objcCompiler, name: "objc")
  }}

  public static let gnustepConfig: URL? = Tools.findTool(name: "gnustep-config")
  #if os(macOS)
  public static let objcCflags: [String] = ["-x", "objective-c"]
  #else
  public static let objcCflags: [String] = Tools.parseArgs(try! Tools.execWithOutput(Tools.gnustepConfig!, ["--objc-flags"]).stdout)
  #endif
  public static var requireGNUStep: URL { get throws {
    try self.requireTool(Self.gnustepConfig, name: "gnustep-config")
  }}

  #if os(macOS)
  public static let objcxxCflags: [String] = ["-x", "objective-c++"]
  #else
  public static let objcxxCflags: [String] = Tools.objcCflags
  #endif

  #if os(macOS)
  public static let objcLinkerFlags: [String] = ["-lobjc"]
  #else
  public static let objcLinkerFlags: [String] = Tools.parseArgs(try! Tools.execWithOutput(Tools.gnustepConfig!, ["--objc-libs", "--base-libs"]).stdout)
  #endif

  public static let lipo: URL? = Tools.findTool(name: "lipo")

  public static let ar: URL? = Tools.findTool(name: "ar", envName: "AR")
  public static var requireAR: URL { get throws {
    try self.requireTool(Self.ar, name: "ar")
  }}

  public static let pkgconfig: URL? = Tools.findTool(name: "pkgconf", envName: "PKG_CONFIG", aliases: ["pkg-config", "pkgconfig"])

  public static let sh: URL? = Tools.findTool(name: "sh", aliases: ["zsh", "bash", "fish"])

  public static let cmake: URL? = Tools.findTool(name: "cmake")

  public static let make: URL? = Tools.findTool(name: "make")

  public static let ninja: URL? = Tools.findTool(name: "ninja", envName: "NINJA")

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
