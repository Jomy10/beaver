import Foundation

@TargetBaseWrapper
@TargetWrapper
@LibraryWrapper
public enum AnyLibrary: ~Copyable, Sendable {
  case c(CLibrary)
  case cmake(CMakeLibrary)

  public typealias ArtifactType = LibraryArtifactType
}
