public protocol ArtifactTypeProtocol: Equatable, Hashable, Sendable {
  func asArtifactType() -> ArtifactType
}

public enum ArtifactType: Equatable, Hashable, Sendable {
  case executable(ExecutableArtifactType)
  case library(LibraryArtifactType)
}

public enum ExecutableArtifactType: ArtifactTypeProtocol, Equatable, Hashable, Sendable {
  case executable
  /// a macOS app
  case app

  public func asArtifactType() -> ArtifactType {
    .executable(self)
  }
}

public enum LibraryArtifactType: ArtifactTypeProtocol, Equatable, Hashable, Sendable {
  /// A dynamic library callable through C
  case dynlib
  case staticlib
  case pkgconfig
  // framework/xcframework: see https://bitmountn.com/difference-between-framework-and-xcframework-in-ios/
  /// macOS framework
  case framework
  case xcframework
  /// A dynamic library callable through the specified `Language`
  case dynamiclanglib(Language)
  case staticlanglib(Language)

  public func asArtifactType() -> ArtifactType {
    .library(self)
  }
}
