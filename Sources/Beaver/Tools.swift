import Foundation
import Platform
import ColorizeSwift

struct Tools {
  static func which(_ cmdName: String) -> URL? {
    let env = ProcessInfo.processInfo.environment
    let exts = env["PATHEXT"] != nil ? env["PATHEXT"]!.split(separator: ";") : [""]
    if let paths = env["PATH"]?.split(separator: PATH_LIST_SEPARATOR) {
      for path in paths {
        let pathURL = URL(fileURLWithPath: String(path))
        for ext in exts {
          let exeURL = pathURL.appendingPathComponent("\(cmdName)\(ext)")
          if FileManager.default.isExecutableFile(atPath: exeURL.path) && !exeURL.isDirectory {
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
          // TODO: generic warning
          print("[WARN] Environment variable \"envName\" exists, but doesn't point to a valid executable")
        } else if toolURL.isDirectory {
          print("[WARN] Environment variable \"envName\" exists, but points to a directory")
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

  struct ProcessError: Error {
    let terminationStatus: Int32
    let reason: Process.TerminationReason
  }

  // TODO: withPipes: (Pipe, Pipe)?
  //       printingCommandTo: e.g. .stderr
  static func exec(_ cmdURL: URL, _ args: [String], baseDir: URL = URL.currentDirectory()) async throws {
    let task = Process()
    let stderrPipe = Pipe()
    let stdoutPipe = Pipe()
    stderrPipe.fileHandleForReading.readabilityHandler = { handle in
      let data: Data = handle.availableData
      if data.count == 0 {
        handle.readabilityHandler = nil
      } else {
        print(String(data: data, encoding: .utf8)!, to: .stderr)
      }
    }
    stdoutPipe.fileHandleForReading.readabilityHandler = { handle in
      let data: Data = handle.availableData
      if data.count == 0 {
        handle.readabilityHandler = nil
      } else {
        print(String(data: data, encoding: .utf8)!, to: .stdout)
      }
    }

    task.standardError = stderrPipe
    task.standardOutput = stdoutPipe
    task.executableURL = cmdURL
    task.arguments = args
    task.currentDirectoryURL = baseDir
    task.environment = ProcessInfo.processInfo.environment
    print((cmdURL.path + " " + args.joined(separator: " ")).darkGray(), to: .stderr)
    try task.run()
    task.waitUntilExit()

    if task.terminationStatus != 0 {
      throw ProcessError(terminationStatus: task.terminationStatus, reason: task.terminationReason)
    }
  }

  /// Statics are lazy variables
  static let cc: URL? = Tools.findTool(name: "cc", envName: "CC", aliases: ["clang", "gcc", "zig", "icc"])
  static let ccExtraArgs: [String]? = {
    if Self.cc?.lastPathComponent.split(separator: ".").first == "zig" {
      return ["cc"]
    } else {
      return nil
    }
  }()

  static let ar: URL? = Tools.findTool(name: "ar", envName: "AR")
}
