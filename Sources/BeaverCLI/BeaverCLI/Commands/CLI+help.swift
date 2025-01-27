import Foundation
import CLIPackage

extension BeaverCLI {
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
    \(commandName) [command] [options]

    COMMANDS
    """)
    self.printHelpPart("build [target]", "Build a target. When no target is provided, all targets in the current project will be built.", terminalWidth: terminalWidth)
    self.printHelpPart("run [target]", "Run a target. Pass arguments to your executable using \"-- [args...]\"", terminalWidth: terminalWidth)
    self.printHelpPart("clean", "Clean the build folder and cache", terminalWidth: terminalWidth)
    self.printHelpPart("init [--file=] [--project=] [--buildDir=]", "Initialize a new beaver project (cannot be overridden). Optionally pass a filename to use for your script (default: beaver.rb).", terminalWidth: terminalWidth)
    self.printHelpPart("list [project|--targets]", "List targets or projects that can be used", terminalWidth: terminalWidth)

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
}
