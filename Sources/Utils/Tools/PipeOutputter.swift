import Foundation

/// Outputs data received by a pipe, line by line, where each line is prefixed by a prefix string
@usableFromInline
final class PipeOutputter: Sendable {
  let pipe: Pipe
  let outputStream: IOStream
  let context: MessageHandler.MessageVisibility
  let prefix: String

  @usableFromInline
  init(pipe: Pipe, outputStream: IOStream, context: MessageHandler.MessageVisibility, prefix: String) {
    self.pipe = pipe
    self.outputStream = outputStream
    self.context = context
    self.prefix = prefix
  }

  // TODO: why hanging?
  @usableFromInline
  func spawn() -> Task<(), any Error> {
    // TODO: priority -> when compiling lower, when running, higher
    Task { [self = self] in
      var bytes: [UInt8] = []
      let newLine = Character("\n").asciiValue!
      for try await byte in pipe.fileHandleForReading.bytes {
        bytes.append(byte)
        if byte == newLine {
          let data = bytes.withUnsafeMutableBufferPointer { data in
            Data(
              bytesNoCopy: UnsafeMutableRawPointer(data.baseAddress!),
              count: data.count,
              deallocator: .none
            )
          }
          let string = String(data: data, encoding: .utf8)!
          //let str = if let prefix = self.prefix { prefix + string } else { string }
          MessageHandler.print(self.prefix + string, to: self.outputStream, context: self.context, terminator: "")
          bytes.removeAll(keepingCapacity: true)
          //MessageHandler.print(String(bytes))
        }
      } // end for

      if bytes.count > 0 {
        let data = bytes.withUnsafeMutableBufferPointer { data in
          Data(
            bytesNoCopy: UnsafeMutableRawPointer(data.baseAddress!),
            count: data.count,
            deallocator: .none
          )
        }
        let string = String(data: data, encoding: .utf8)!
        for string in string.split(whereSeparator: \.isNewline) {
          MessageHandler.print(self.prefix + string, to: self.outputStream, context: self.context, terminator: bytes.last == newLine ? "" : "\n")
        }
      }
    }
  }
}
