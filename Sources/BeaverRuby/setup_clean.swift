import RubyGateway

public struct RubyCleanupError: Error {
  let code: Int32
}

public func cleanupRuby() throws(RubyCleanupError) {
  let code = Ruby.cleanup()
  if code != 0 {
    throw RubyCleanupError(code: code)
  }
}

public func setupRuby() {
  _ = Ruby.softSetup()
}
