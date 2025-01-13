import Foundation
@testable import Beaver

#if DEBUG
let optMode = "debug"
#else
let optMode = "release"
#endif

let beaverExeURL = URL(filePath: ".build/\(optMode)/beaver")

func execOutput(_ cmdURL: URL, _ args: [String], baseDir: URL = URL.currentDirectory()) async throws -> (stdout: String, stderr: String) {
  let task = Process()
  let stderrPipe = Pipe()
  let stdoutPipe = Pipe()
  task.standardError = stderrPipe
  task.standardOutput = stdoutPipe
  task.executableURL = cmdURL
  task.arguments = args
  task.currentDirectoryURL = baseDir
  task.environment = [:]
  print(cmdURL.path + " " + args.joined(separator: " "))
  try task.run()
  task.waitUntilExit()

  if task.terminationStatus != 0 {
    throw Tools.ProcessError(terminationStatus: task.terminationStatus, reason: task.terminationReason)
  }

  return (
    stdout: String(data: stdoutPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8)!,
    stderr: String(data: stderrPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8)!
  )
}
