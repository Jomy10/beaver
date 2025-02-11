import ProgressIndicatorsFFI

extension String? {
  func withCString<Result>(_ closure: (UnsafePointer<CChar>?) throws -> Result) rethrows -> Result {
    if let str = self {
      return try str.withCString(closure)
    } else {
      return try closure(nil)
    }
  }
}

public final class ProgressIndicators: @unchecked Sendable {
  private var ptr: UnsafeRawPointer?
  private var tick_thread: Task<(), Never>?

  public enum Stream: UInt32 {
    case stdout = 0
    case stderr = 1
  }

  private init(stream: Stream) {
    self.ptr = ProgressIndicatorsFFI.indicators_start(ProgressIndicatorsFFI.Stream(stream.rawValue))
    self.tick_thread = nil
    self.tick_thread = Task.detached(priority: .background) {
      while true {
        await self.tick()
        try? await Task.sleep(for: .seconds(0.1), tolerance: .seconds(0.5))
      }
    }
  }

  public static func start(stream: Stream) -> ProgressIndicators {
    ProgressIndicators(stream: stream)
  }

  func tick() async {
    await withCheckedContinuation { continuation in
      ProgressIndicatorsFFI.indicators_tick(self.ptr!)
      continuation.resume()
    }
  }

  func stop() async {
    self.tick_thread!.cancel()
    _ = await self.tick_thread!.result
    await withCheckedContinuation { continuation in
      ProgressIndicatorsFFI.indicators_stop(self.ptr!)
      continuation.resume()
    }
    self.ptr = nil
    self.tick_thread = nil
  }

  func stop_detached() {
    let thread = self.tick_thread!
    let ptr = self.ptr!
    Task {
      thread.cancel()
      _ = await thread.result
      ProgressIndicatorsFFI.indicators_stop(ptr)
    }
  }

  public func println(_ message: String) async {
    await withCheckedContinuation { continuation in
      message.withCString { ptr in
        ProgressIndicatorsFFI.indicators_println(self.ptr!, ptr)
      }
      continuation.resume()
    }
  }

  public func println(_ components: Any..., separator: String = " ") async {
    await self.println(components.map { String(describing: $0) }.joined(separator: separator))
  }

  public func registerSpinner(
    message: String? = nil,
    styleString: String? = nil,
    tickChars: String? = nil,
    prefix: String? = nil
  ) async -> ProgressBar {
    await withCheckedContinuation { continuation in
      let spinnerPtr = message.withCString { cmessage in
        styleString.withCString { cstyleString in
          tickChars.withCString { ctickChars in
            prefix.withCString { cprefix in
              ProgressIndicatorsFFI.indicators_register_spinner(self.ptr!, cmessage, cstyleString, ctickChars, cprefix)
            }
          }
        }
      }
      continuation.resume(returning: ProgressBar(spinnerPtr))
    }
  }

  deinit {
    self.stop_detached()
  }
}

public actor ProgressBar {
  private nonisolated(unsafe) var ptr: UnsafeRawPointer? = nil

  init(_ ptr: UnsafeRawPointer) {
    self.ptr = ptr
  }

  public func setMessage(_ message: String) {
    message.withCString { ptr in
      ProgressIndicatorsFFI.progress_bar_set_message(self.ptr!, message)
    }
  }

  public func setMessage(_ components: Any..., separator: String = " ") {
    self.setMessage(components.map { String(describing: $0) }.joined(separator: separator))
  }

  public var message: String {
    let cstr = ProgressIndicatorsFFI.progress_bar_message(self.ptr!)
    let str = String(cString: cstr)
    rs_cstring_destroy(cstr)
    return str
  }

  public func finish(message: String? = nil) async {
    await withCheckedContinuation { continuation in
      message.withCString { messagePtr in
        ProgressIndicatorsFFI.progress_bar_finish(self.ptr!, messagePtr)
      }
      continuation.resume()
    }
    self.ptr = nil
  }

  deinit {
    if let ptr = self.ptr {
      ProgressIndicatorsFFI.progress_bar_finish(ptr, nil)
    }
  }
}

//public struct ProgressIndicators: ~Copyable, @unchecked Sendable {
//  private let progress: UnsafeRawPointer
//  private var thread: Task<(), Never>

//  public enum Stream {
//    case stdout
//    case stderr
//  }

//  public init(stream: Stream) {
//    let ffi_stream: ProgressIndicatorsFFI.Stream
//    switch (stream) {
//      case .stdout: ffi_stream = STREAM_STDOUT
//      case .stderr: ffi_stream = STREAM_STDERR
//    }
//    self.progress = ProgressIndicatorsFFI.start_progress(ffi_stream)
//    let progress = self.progress
//    self.thread = Task.detached(priority: .background, operation: {
//      while true {
//        ProgressIndicatorsFFI.tick_progress(progress)
//        try? await Task.sleep(for: .seconds(0.1), tolerance: .seconds(0.5))
//      }
//    })
//  }

//  public func registerSpinner(
//    message: String? = nil,
//    styleString: String? = nil,
//    tickChar: String? = nil,
//    prefix: String? = nil
//  ) -> ProgressBar {
//    let messageCString = styleString?.utf8CString.withUnsafeBufferPointer { $0.baseAddress! }
//    let styleCString = styleString?.utf8CString.withUnsafeBufferPointer { $0.baseAddress! }
//    let tickCharCString = tickChar?.utf8CString.withUnsafeBufferPointer { $0.baseAddress! }
//    let prefixCString = prefix?.utf8CString.withUnsafeBufferPointer { $0.baseAddress! }

//    let spinner = ProgressIndicatorsFFI.register_spinner(self.progress, messageCString, styleCString, tickCharCString, prefixCString)
//    return ProgressBar(spinner)
//  }

//  public func println(_ message: String) {
//    _ = message.withCString { cstr in
//      ProgressIndicatorsFFI.progress_println(self.progress, cstr)
//    }
//  }

//  public func println(_ components: Any..., separator: String = " ") {
//    self.println(components.map { component in String(describing: component) }.joined(separator: separator))
//  }

//  public var isColorEnabled: Bool {
//    ProgressIndicatorsFFI.progress_is_color_enabled(self.progress)
//  }

//  deinit {
//    self.thread.cancel()
//    stop_progress(self.progress)
//  }
//}

//public actor ProgressBar {
//  private nonisolated(unsafe) var progressBar: UnsafeMutableRawPointer?
//  private var finished: Bool

//  init(_ progressBar: UnsafeMutableRawPointer) {
//    self.progressBar = progressBar
//    self.finished = true
//  }

//  public func finish(message: String? = nil) {
//    let messageCString = message?.utf8CString.withUnsafeBufferPointer { $0.baseAddress! }
//    ProgressIndicatorsFFI.finish_spinner(self.progressBar!, messageCString)
//    self.finished = true
//    self.progressBar = nil
//  }

//  public func setMesssage(_ message: String) {
//    message.withCString { str in
//      ProgressIndicatorsFFI.spinner_set_message(self.progressBar!, str)
//    }
//  }

//  deinit {
//    if !self.finished {
//      ProgressIndicatorsFFI.finish_spinner(self.progressBar!, "cancelled")
//      self.progressBar = nil
//      self.finished = true
//    }
//  }
//}
