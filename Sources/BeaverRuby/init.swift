import RubyGateway

public typealias RbError = RubyGateway.RbError

struct RubyInitializeError: Error {}

public func initRuby() throws {
  //try RbGateway.vm.explicitSetup()
  //if !Ruby.softSetup() {
  //  throw RubyInitializeError()
  //}
}

@discardableResult
public func deinitRuby() -> Int32 {
  Ruby.cleanup()
}
