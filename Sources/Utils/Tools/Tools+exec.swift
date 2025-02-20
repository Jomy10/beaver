import Foundation
import ColorizeSwift

extension Tools {
  //@available(*, deprecated, message: "Use execWithOutput")
  //private static func _exec(_ cmdURL: URL, _ args: [String]) throws {
  //  let task = Process()
  //  let stderrPipe = Pipe()
  //  task.standardError = stderrPipe
  //  task.executableURL = cmdURL
  //  task.arguments = args
  //  task.environment = ProcessInfo.processInfo.environment
  //  try task.run()
  //  task.waitUntilExit()

  //  if task.terminationStatus != 0 {
  //    throw ExecutionError(stderr: String(data: stderrPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? "<error reading stderr>")
  //  }
  //}

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

  /// Output to stderr/stdout with a prefix before each line of `[context]`
  @inlinable
  public static func exec(_ cmdURL: URL, _ args: [String], baseDir: URL = URL.currentDirectory(), context: String) async throws {
    let contextString: String = "[\(context)] "
    let task = Process()
    let outputPipe = Pipe()
    let outputter = PipeOutputter(pipe: outputPipe, outputStream: .stderr, context: .shellOutputStderr, prefix: contextString)

    task.standardError = outputPipe
    task.standardOutput = outputPipe
    task.executableURL = cmdURL
    task.arguments = args
    task.currentDirectoryURL = baseDir
    task.environment = ProcessInfo.processInfo.environment
    MessageHandler.print(((cmdURL.path + " " + args.joined(separator: " ")).prependingIfNeeded(contextString)).darkGray(), to: .stderr, context: .shellCommand)
    let outputTask = outputter.spawn()
    try task.run()

    await task.waitUntilExitAsync()
    _ = try await outputTask.value

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

    await task.waitUntilExitAsync()

    if task.terminationStatus != 0 {
      throw ProcessError(terminationStatus: task.terminationStatus, reason: task.terminationReason)
    }
  }

  /// Output to stderr/stdout and don't print the command
  @inlinable
  public static func execSilent(_ cmdURL: URL, _ args: [String], baseDir: URL = URL.currentDirectory()) async throws {
    let task = Process()

    task.standardError = FileHandle.standardError
    task.standardOutput = FileHandle.standardOutput
    task.executableURL = cmdURL
    task.arguments = args
    task.currentDirectoryURL = baseDir
    task.environment = ProcessInfo.processInfo.environment

    try task.run()

    MessageHandler.debug((cmdURL.path + " " + args.joined(separator: " ")).darkGray(), context: .shellCommand)

    await task.waitUntilExitAsync()

    if task.terminationStatus != 0 {
      throw ProcessError(terminationStatus: task.terminationStatus, reason: task.terminationReason)
    }
  }

  @inlinable
  public static func execSilentSync(_ cmdURL: URL, _ args: [String], baseDir: URL = URL.currentDirectory()) throws {
    let task = Process()

    task.standardError = FileHandle.standardError
    task.standardOutput = FileHandle.standardOutput
    task.executableURL = cmdURL
    task.arguments = args
    task.currentDirectoryURL = baseDir
    task.environment = ProcessInfo.processInfo.environment

    try task.run()

    MessageHandler.debug((cmdURL.path + " " + args.joined(separator: " ")).darkGray(), context: .shellCommand)

    task.waitUntilExit()

    if task.terminationStatus != 0 {
      throw ProcessError(terminationStatus: task.terminationStatus, reason: task.terminationReason)
    }
  }
}
