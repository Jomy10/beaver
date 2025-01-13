public protocol ExpressibleByArgument {
  init(argument: String) throws
}

extension Optional: ExpressibleByArgument
where Wrapped: ExpressibleByArgument
{
  public init(argument: String) throws {
    self = try Wrapped.init(argument: argument)
  }
}
