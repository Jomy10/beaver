import RubyGateway

extension Result: @retroactive RbObjectConvertible
where
  Success: FailableRbObjectConvertible,
  Failure == any Error
{
  public init?(_ value: RbObject) {
    do {
      self = .success(try Success(value))
    } catch let error {
      self = .failure(error)
    }
  }

  public var rubyObject: RbObject {
    fatalError("unimplemented")
  }
}
