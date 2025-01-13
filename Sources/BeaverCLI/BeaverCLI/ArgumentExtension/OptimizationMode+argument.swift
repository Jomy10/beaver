import CLIPackage
import Beaver

extension OptimizationMode: ExpressibleByArgument {
  public init(argument: String) throws {
    switch (argument.lowercased()) {
      case "debug": self = .debug
      case "release": self = .release
      default: throw ValidationError.notConvertible(argument: argument, to: Self.self)
    }
  }
}
