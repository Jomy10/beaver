import Foundation
import CLIPackage

extension URL: ExpressibleByArgument {
  public init(argument: String) throws {
    guard let v = URL(string: argument) else {
      throw ValidationError.notConvertible(argument: argument, to: Self.self)
    }
    self = v
  }
}
