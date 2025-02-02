import Foundation

// https://stackoverflow.com/a/67107537/14874405
#if canImport(Darwin)
import Darwin

typealias Swift_Demangle = @convention(c) (_ mangledName: UnsafePointer<UInt8>?,
                                           _ mangledNameLength: Int,
                                           _ outputBuffer: UnsafeMutablePointer<UInt8>?,
                                           _ outputBufferSize: UnsafeMutablePointer<Int>?,
                                           _ flags: UInt32) -> UnsafeMutablePointer<Int8>?

func swift_demangle(_ mangled: String) -> String? {
  let RTLD_DEFAULT = dlopen(nil, RTLD_NOW)
  if let sym = dlsym(RTLD_DEFAULT, "swift_demangle") {
    let f = unsafeBitCast(sym, to: Swift_Demangle.self)
    if let cString = f(mangled, mangled.count, nil, nil, 0) {
      defer { cString.deallocate() }
      return String(cString: cString)
    }
  }
  return nil
}
#else
func swift_demangle(_ mangled: String) -> String? {
  return mangled
}
#endif

public struct CallStackFormatter {
  public static func symbols() -> String {
    Thread.callStackSymbols
      .map { symbol in
        let symbolStart = symbol.index(symbol.startIndex, offsetBy: 59)
        guard let plusIndex = symbol.lastIndex(of: "+") else { return symbol }
        let symbolEnd = symbol.index(plusIndex, offsetBy: -1)

        let prefix = symbol[symbol.startIndex..<symbolStart]
        let symbolMangledName = symbol[symbolStart..<symbolEnd]
        let postfix = symbol[symbolEnd...]

        let mangledName = String(symbolMangledName)
        return prefix + (swift_demangle(mangledName) ?? mangledName) + postfix
      }
      .joined(separator: "\n")
  }
}
