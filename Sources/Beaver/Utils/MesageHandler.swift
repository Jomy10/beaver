//import TaskProgress
import ProgressIndicators
import ColorizeSwift
import Utils

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

struct MessageHandler {
  private static let data: AsyncRWLock<Self.Data> = AsyncRWLock(.init())
  private nonisolated(unsafe) static var progress: ProgressIndicators? = nil
  /// Should only be used on the main thread by Beaver, so no locking mechanism is provided here
  private nonisolated(unsafe) static var messageVisibility: MessageVisibility = MessageVisibility.default

  struct Data: ~Copyable {
    var targetToSpinner: [TargetRef:ProgressBar] = [:]
  }

  struct NoTaskError: Error, @unchecked Sendable {
    let id: Any
  }

  struct MessageVisibility: OptionSet {
    let rawValue: UInt32

    /// shell commands, outputted in grey showing what the library is doing
    static let shellCommand       = Self(rawValue: 1 << 0)
    static let shellOutputStderr  = Self(rawValue: 1 << 1)
    static let shellOutputStdout  = Self(rawValue: 1 << 2)
    static let trace              = Self(rawValue: 1 << 3)
    static let debug              = Self(rawValue: 1 << 4)
    static let info               = Self(rawValue: 1 << 5)
    static let warning            = Self(rawValue: 1 << 6)
    static let error              = Self(rawValue: 1 << 7)
    static let sql                = Self(rawValue: 1 << 8)

    #if DEBUG
    static let `default`: Self = [.shellCommand, .shellOutputStderr, .shellOutputStdout, .trace, .debug, .info, .warning, .error, .sql]
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

  public static func setColorEnabled(_ val: Bool? = nil) {
    String.isColorizationEnabled = val ?? Self.terminalColorEnabled
  }

  public static func enableIndicators() async {
    Self.progress = ProgressIndicators.start(stream: .stderr)
  }

  public static func closeIndicators() async {
    Self.progress = nil
    await Self.data.write { data in
      data.targetToSpinner.removeAll()
    }
  }

  public static func withIndicators<Result, E>(_ cb: () async throws(E) -> Result) async rethrows -> Result {
    await self.enableIndicators()
    let value = try await cb()
    await self.closeIndicators()
    return value
  }

  public static func getSpinner(targetRef: TargetRef) async -> ProgressBar? {
    return await self.data.read { data in data.targetToSpinner[targetRef] }
  }

  public static func addTask(_ message: String, targetRef: TargetRef? = nil) async {
    let spinner = Self.progress!.registerSpinner(message: message)
    if let targetRef = targetRef {
      await self.data.write { data in
        data.targetToSpinner[targetRef] = spinner
      }
    }
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
      IO.print(message, to: IOStream.stderr)
    }
  }

  public static func print(_ message: String, to stream: IOStream, context: MessageVisibility? = nil) {
    if !Self.checkContext(context) { return }

    if let progress = Self.progress {
      //ProgressIndicators.global.globalMessage(message)
      progress.println(message)
    } else {
      IO.print(message, to: stream)
    }
  }

  public enum LogLevel {
    case trace
    case warning
    case error

    var format: String {
      switch (self) {
        case .trace: "TRACE".bold()
        case .warning: "WARN".yellow()
        case .error: "ERR".red()
      }
    }

    var messageVisibility: MessageVisibility {
      switch (self) {
        case .trace: .trace
        case .warning: .warning
        case .error: .error
      }
    }
  }

  public static func log(_ message: String, level: LogLevel, context: MessageVisibility? = nil) {
    self.print("[\(level.format)] \(message)", context: (context ?? []).union(level.messageVisibility))
  }

  public static func warn(_ message: String, context: MessageVisibility? = nil) {
    self.log(message, level: .warning, context: context)
  }

  public static func trace(_ message: String, context: MessageVisibility? = nil) {
    self.log(message, level: .trace, context: context)
  }

  public static func error(_ message: String, context: MessageVisibility? = nil) {
    self.log(message, level: .error, context: context)
  }
}
