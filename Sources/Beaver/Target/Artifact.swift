public protocol ArtifactTypeProtocol: Equatable, Hashable, Sendable {
  init?(_ string: String)
  func asArtifactType() -> ArtifactType
  /// The object type which needs to be compiled for this artifact
  var cObjectType: CObjectType? { get }
}

public enum ArtifactType: Equatable, Hashable, Sendable {
  case executable(ExecutableArtifactType)
  case library(LibraryArtifactType)

  var cObjectType: CObjectType? {
    switch (self) {
      case .executable(let artifact): artifact.cObjectType
      case .library(let artifact): artifact.cObjectType
    }
  }
}

public enum ExecutableArtifactType: ArtifactTypeProtocol, Equatable, Hashable, Sendable {
  case executable
  /// a macOS app
  case app

  public init?(_ string: String) {
    switch (string) {
      case "executable": self = .executable
      case "app": self = .app
      default: return nil
    }
  }

  public func asArtifactType() -> ArtifactType {
    .executable(self)
  }

  public var cObjectType: CObjectType? {
    return .static
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

  public init?(_ string: String) {
    switch (string) {
      case "dynlib": self = .dynlib
      case "staticlib": self = .staticlib
      case "pkgconfig": self = .pkgconfig
      case "framework": self = .framework
      case "xcframework": self = .xcframework
      default: return nil
    }
  }

  public func asArtifactType() -> ArtifactType {
    .library(self)
  }

  public var cObjectType: CObjectType? {
    switch (self) {
      case .dynlib: return .dynamic
      case .staticlib: return .static
      default: return nil
    }
  }
}

public enum CObjectType: Equatable, Hashable, Sendable {
  case dynamic
  case `static`
}
