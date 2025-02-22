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
  public static func execWithOutput(_ cmdURL: URL, _ args: [String], baseDir: URL = URL.currentDirectory()) async throws -> (stderr: String, stdout: String) {
    let task = Process()
    let stderrPipe = Pipe()
    let stdoutPipe = Pipe()
    task.standardError = stderrPipe
    task.standardOutput = stdoutPipe
    task.executableURL = cmdURL
    task.arguments = args
    task.currentDirectoryURL = baseDir
    task.environment = ProcessInfo.processInfo.environment

    let idx = await Self.processes.pushEnd(task)
    try task.run()
    MessageHandler.print(((cmdURL.path + " " + args.joined(separator: " "))).darkGray(), to: .stderr, context: .shellCommand)
    await task.waitUntilExitAsync()
    await Self.processes.remove(at: idx)

    if task.terminationStatus != 0 {
      throw ProcessError(terminationStatus: task.terminationStatus, reason: task.terminationReason)
    }

    let stdout = if let data = try stdoutPipe.fileHandleForReading.readToEnd() { String(data: data, encoding: .utf8)! } else { String() }
    let stderr = if let data = try stderrPipe.fileHandleForReading.readToEnd() { String(data: data, encoding: .utf8)! } else { String() }

    return (stdout, stderr)
  }

  /// Reduce usage of this function because processes are not interrupted on signal
  @inlinable
  public static func execWithOutputSync(_ cmdURL: URL, _ args: [String], baseDir: URL = URL.currentDirectory()) throws -> (stderr: String, stdout: String) {
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
    MessageHandler.print(((cmdURL.path + " " + args.joined(separator: " "))).darkGray(), to: .stderr, context: .shellCommand)
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
  public static func execWithExitCode(_ cmdURL: URL, _ args: [String], baseDir: URL = URL.currentDirectory()) async throws -> Int {
    let task = Process()
    task.executableURL = cmdURL
    task.arguments = args
    task.currentDirectoryURL = baseDir
    task.environment = ProcessInfo.processInfo.environment

    let idx = await Self.processes.pushEnd(task)
    try task.run()
    await task.waitUntilExitAsync()
    await Self.processes.remove(at: idx)

    return Int(task.terminationStatus)
  }

  /// Reduce usage of this function to a minimum
  @inlinable
  public static func execWithExitCodeSync(_ cmdURL: URL, _ args: [String], baseDir: URL = URL.currentDirectory()) throws -> Int {
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


    let idx = await Self.processes.pushEnd(task)
    try task.run()
    await task.waitUntilExitAsync()
    await Self.processes.remove(at: idx)

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

    let idx = await Self.processes.pushEnd(task)
    try task.run()
    await task.waitUntilExitAsync()
    await Self.processes.remove(at: idx)

    if task.terminationStatus != 0 {
      throw ProcessError(terminationStatus: task.terminationStatus, reason: task.terminationReason)
    }
  }

  /// Output immediately to stderr/stdout
  @available(*, deprecated, message: "use async versions")
  @inlinable
  public static func execSync(_ cmdURL: URL, _ args: [String], baseDir: URL = URL.currentDirectory()) throws {
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

    let idx = await Self.processes.pushEnd(task)
    try task.run()
    MessageHandler.debug((cmdURL.path + " " + args.joined(separator: " ")).darkGray(), context: .shellCommand)
    await task.waitUntilExitAsync()
    await Self.processes.remove(at: idx)

    if task.terminationStatus != 0 {
      throw ProcessError(terminationStatus: task.terminationStatus, reason: task.terminationReason)
    }
  }

  @available(*, deprecated, message: "use async versions")
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
