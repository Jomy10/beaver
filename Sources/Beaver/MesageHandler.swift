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

    static let `default`: Self = [.shellCommand]
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
    //await self.data.write { data in data.indicatorsEnabled = false }
    //ProgressIndicators.global.setCanClose()
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

  @available(*, deprecated)
  public static func print(_ message: String, task: ProgressBar) async {
    if let progress = Self.progress {
      //task.setMessage(message)
      // TODO!
      progress.println(message)
    } else {
      IO.print(message, to: IOStream.stderr)
    }
  }

  @available(*, deprecated)
  public static func print(_ message: String, targetRef: TargetRef) async throws(NoTaskError) {
    guard let task = await self.data.read({ $0.targetToSpinner[targetRef] }) else {
      throw NoTaskError(id: targetRef)
    }
    await self.print(message, task: task)
  }

  private static func checkContext(_ context: MessageVisibility?) -> Bool {
    if let context = context {
      return self.messageVisibility.contains(context)
    } else {
      return true
    }
  }

  public static func print(_ message: String, context: MessageVisibility? = nil) async {
    if !Self.checkContext(context) { return }

    if let progress = Self.progress {
      //ProgressIndicators.global.globalMessage(message)
      progress.println(message)
    } else {
      IO.print(message, to: IOStream.stderr)
    }
  }

  public static func print(_ message: String, to stream: IOStream, context: MessageVisibility? = nil) async {
    if !Self.checkContext(context) { return }

    if let progress = Self.progress {
      //ProgressIndicators.global.globalMessage(message)
      progress.println(message)
    } else {
      IO.print(message, to: stream)
    }
  }

  public enum LogLevel {
    case warning
    case error

    var format: String {
      switch (self) {
        case .warning: "WARN".yellow()
        case .error: "ERR".red()
      }
    }
  }

  public static func log(_ message: String, level: LogLevel, context: MessageVisibility? = nil) async {
    if !Self.checkContext(context) { return }

    await self.print("[\(level.format)] \(message)")
  }

  public static func warn(_ message: String, context: MessageVisibility? = nil) async {
    await self.log(message, level: .warning, context: context)
  }
}
