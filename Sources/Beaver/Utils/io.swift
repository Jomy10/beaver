#if canImport(Darwin)
import Darwin
#elseif canImport(Glibc)
import Glibc
#elseif canImport(Musl)
import Musl
#else
#warning("Unhandled platform in OctoIO, all output will be redirected to stdout (pull requests are welcome)")
#endif

public enum IOStream: TextOutputStream {
  case stdout
  case stderr

  #if canImport(Darwin)
  var to: UnsafeMutablePointer<FILE> {
    switch (self) {
      case .stdout: return Darwin.stdout
      case .stderr: return Darwin.stderr
    }
  }
  #elseif canImport(Glibc)
  var to: UnsafeMutablePointer<FILE> {
    switch (self) {
      case .stdout: return Glibc.stdout
      case .stderr: return Glibc.stderr
    }
  }
  #elseif canImport(Musl)
  var to: UnsafeMutablePointer<FILE> {
    switch (self) {
      case .stdout: return Musl.stdout
      case .stderr: return Musl.stderr
    }
  }
  #endif

  #if canImport(Darwin) || canImport(Glibc)
  public mutating func write(_ string: String) {
    fputs(string, self.to)
  }
  #else
  public mutating func write(_ string: String) {
    // TODO!!
    print(string)
  }
  #endif
}

public func print(_ msgs: String..., to stream: IOStream) {
  var s = stream
  print(msgs.joined(separator: " "), to: &s)
}

struct IO {
  public static func print(_ msgs: String..., to stream: IOStream) {
    var s = stream
    Swift.print(msgs.joined(separator: " "), to: &s)
  }
}
