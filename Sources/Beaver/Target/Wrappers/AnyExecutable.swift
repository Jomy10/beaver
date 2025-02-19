import Foundation

@TargetBaseWrapper
@TargetWrapper
public enum AnyExecutable: ~Copyable, Sendable {
  case c(CExecutable)
  case cmake(CMakeExecutable)

  public typealias ArtifactType = ExecutableArtifactType
}

extension AnyExecutable: Executable {}
