import Foundation

//@EnumWrapper(TargetBase)
@TargetBaseWrapper
public enum AnyTarget: ~Copyable, Sendable {
  case library(AnyLibrary)
  case executable(AnyExecutable)
}

public enum TargetAccessError: Error {
  /// The target doesn't exist
  case noTarget(named: String)
  /// The target exists, but is not a library
  case notALibrary(named: String)
  /// The target exists, but is not an executable
  case notAnExecutable(named: String)
  /// The target exists, but is not a library
  case notLibrary
  case notExecutable

  case notOfType((any Target & ~Copyable).Type)

  case noCMakeLibrary(cmakeId: String)
}
