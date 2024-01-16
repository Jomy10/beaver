@_cdecl("test_swift")
public func test_swift() -> UnsafePointer<Int8> {
    #if HELLO
    "Hello from swift!".withCString { ptr in ptr }
    #else
    "UNEXPECTED".withCString { ptr in ptr }
    #endif
}

