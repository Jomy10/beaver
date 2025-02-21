import Testing
import Foundation
import Darwin
import Utils
@testable import Beaver

@Test func exampleArguments() async throws {
  let baseURL = URL(filePath: "Examples/Arguments", relativeTo: URL.currentDirectory())

  var (stdout, _) = try Tools.execWithOutput(beaverExeURL, ["helloWorld"], baseDir: baseURL)
  #expect(stdout == "Hello world\n")

  (stdout, _) = try Tools.execWithOutput(beaverExeURL, ["shellCommand"], baseDir: baseURL)
  #expect(stdout == "Hello world!\nHello world!\n")

  (stdout, _) = try Tools.execWithOutput(beaverExeURL, ["printArg", "--argument-name", "warn", "--warn"], baseDir: baseURL)
  #expect(stdout == "true\n")

  (stdout, _) = try Tools.execWithOutput(beaverExeURL, ["printArg", "--argument-name", "warn", "-w"], baseDir: baseURL)
  #expect(stdout == "true\n")

  (stdout, _) = try Tools.execWithOutput(beaverExeURL, ["printArg", "--argument-name", "warn", "--no-warn"], baseDir: baseURL)
  #expect(stdout == "false\n")

  (stdout, _) = try Tools.execWithOutput(beaverExeURL, ["printArg", "--argument-name", "warn"], baseDir: baseURL)
  #expect(stdout == "\n")

  (stdout, _) = try Tools.execWithOutput(beaverExeURL, ["printArg", "--argument-name", "sdl-version"], baseDir: baseURL)
  #expect(stdout == "2\n")

  (stdout, _) = try Tools.execWithOutput(beaverExeURL, ["printArg", "--argument-name", "sdl-version", "--sdl-version", "3"], baseDir: baseURL)
  #expect(stdout == "3\n")

  (stdout, _) = try Tools.execWithOutput(beaverExeURL, ["printArg", "--argument-name", "sdl-version", "-s", "1"], baseDir: baseURL)
  #expect(stdout == "1\n")

  (stdout, _) = try Tools.execWithOutput(beaverExeURL, ["printArg", "--argument-name", "sdl-version"], baseDir: baseURL)
  #expect(stdout == "2\n")

  (stdout, _) = try Tools.execWithOutput(beaverExeURL, ["printArg", "--argument-name", "from-source"], baseDir: baseURL)
  #expect(stdout == "false\n")

  (stdout, _) = try Tools.execWithOutput(beaverExeURL, ["printArg", "--argument-name", "from-source", "--from-source"], baseDir: baseURL)
  #expect(stdout == "true\n")
}
