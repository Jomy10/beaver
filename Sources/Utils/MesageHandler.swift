//import TaskProgress
import ProgressIndicators
import ColorizeSwift

#if canImport(Darwin)
import Darwin
#elseif canImport(Glibc)
import Glibc
#elseif canImport(Musl)
import Musl
#elseif os(Windows)
import ucrt
#else
#warning("Need implementation for current platform to determine terminal context")
#endif

public struct MessageHandler {
  private nonisolated(unsafe) static var progress: ProgressIndicators? = nil
  /// Should only be used on the main thread by Beaver, so no locking mechanism is provided here
  private nonisolated(unsafe) static var messageVisibility: MessageVisibility = MessageVisibility.default

  public struct MessageVisibility: OptionSet, Sendable {
    public let rawValue: UInt32

    public init(rawValue: UInt32) { self.rawValue = rawValue }

    /// shell commands, outputted in grey showing what the library is doing
    public static let shellCommand       = Self(rawValue: 1 << 0)
    public static let shellOutputStderr  = Self(rawValue: 1 << 1)
    public static let shellOutputStdout  = Self(rawValue: 1 << 2)
    public static let trace              = Self(rawValue: 1 << 3)
    public static let debug              = Self(rawValue: 1 << 4)
    public static let info               = Self(rawValue: 1 << 5)
    public static let warning            = Self(rawValue: 1 << 6)
    public static let error              = Self(rawValue: 1 << 7)
    public static let sql                = Self(rawValue: 1 << 8)

    #if DEBUG
    static let `default`: Self = [.shellCommand, .shellOutputStderr, .shellOutputStdout, .trace, .debug, .info, .warning, .error/*, .sql*/]
    #else
    static let `default`: Self = [.shellCommand, .shellOutputStderr, .shellOutputStdout, .info, .warning, .error]
    #endif
  }

  public nonisolated(unsafe) static var terminalColorEnabled: Bool = {
    #if canImport(Darwin) || canImport(Glibc) || canImport(Musl)
    return isatty(STDERR_FILENO) != 0
    #elseif os(Windows)
    return _isatty(_fileno(stderr))
    #else
    return true
    #endif
  }()

  @inlinable
  public static func setColorEnabled(_ val: Bool? = nil) {
    String.isColorizationEnabled = val ?? Self.terminalColorEnabled
  }

  public static func enableIndicators() {
    Self.progress = ProgressIndicators.start(stream: .stderr)
  }

  public static func closeIndicators() {
    Self.progress = nil
    //await Self.data.write { data in
    //  data.targetToSpinner.removeAll()
    //}
  }

  public static func withIndicators<Result, E>(_ cb: () async throws(E) -> Result) async rethrows -> Result {
    self.enableIndicators()
    let value = try await cb()
    self.closeIndicators()
    return value
  }

  public static func newSpinner(_ message: String) -> ProgressBar {
    Self.progress!.registerSpinner(message: message)
  }

  private static func checkContext(_ context: MessageVisibility?) -> Bool {
    if context?.rawValue == 0 { return true }
    if let context = context {
      return self.messageVisibility.contains(context)
    } else {
      return true
    }
  }

  public static func print(_ message: String, context: MessageVisibility? = nil) {
    if !Self.checkContext(context) { return }

    if let progress = Self.progress {
      //ProgressIndicators.global.globalMessage(message)
      progress.println(message)
    } else {
      Utils.print(message, to: IOStream.stderr)
    }
  }

  public static func print(_ message: String, to stream: IOStream, context: MessageVisibility? = nil) {
    if !Self.checkContext(context) { return }

    if let progress = Self.progress {
      //ProgressIndicators.global.globalMessage(message)
      progress.println(message)
    } else {
      Utils.print(message, to: stream)
    }
  }

  public enum LogLevel {
    case trace
    case debug
    case info
    case warning
    case error

    var format: String {
      switch (self) {
        case .trace: "TRACE".bold()
        case .debug: "DEBUG".lightBlue()
        case .info: "INFO".blue()
        case .warning: "WARN".yellow()
        case .error: "ERR".red()
      }
    }

    var messageVisibility: MessageVisibility {
      switch (self) {
        case .trace: .trace
        case .debug: .debug
        case .info: .info
        case .warning: .warning
        case .error: .error
      }
    }
  }

  public static func log(_ message: String, level: LogLevel, context: MessageVisibility? = nil) {
    self.print("[\(level.format)] \(message)", context: (context ?? []).union(level.messageVisibility))
  }

  public static func trace(_ message: String, context: MessageVisibility? = nil) {
    self.log(message, level: .trace, context: context)
  }

  public static func debug(_ message: String, context: MessageVisibility? = nil) {
    self.log(message, level: .debug, context: context)
  }

  public static func info(_ message: String, context: MessageVisibility? = nil) {
    self.log(message, level: .info, context: context)
  }

  public static func warn(_ message: String, context: MessageVisibility? = nil) {
    self.log(message, level: .warning, context: context)
  }

  public static func error(_ message: String, context: MessageVisibility? = nil) {
    self.log(message, level: .error, context: context)
  }
}
