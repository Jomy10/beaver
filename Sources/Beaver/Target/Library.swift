import Foundation

public protocol Library: Target {
  associatedtype ArtifactType = LibraryArtifactType

  /// Flags to use when linking to this library
  func linkerFlags() async throws -> [String]
  func publicCflags() async throws -> [String]
  func publicHeaders(baseDir: URL) async throws -> [URL]
  func artifactOutputDir(projectBuildDir: URL, forArtifact artifact: LibraryArtifactType?) async throws -> URL
}

public enum LibraryArtifactType: Equatable, Hashable, Sendable {
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
}

public struct LibraryRef: Sendable {
  /// The name of the library
  let name: String
  /// The project this library belongs to
  let project: ProjectRef
  /// The artifact to link against
  let artifact: LibraryArtifactType?

  public enum ParsingError: Error {
    case unexpectedNoComponents
    case malformed(String)
    /// No project exists with the specified name
    case unknownProject(String)
  }

  public init(name: String, project: ProjectRef, artifact: LibraryArtifactType) {
    self.name = name
    self.project = project
    self.artifact = artifact
  }

  /// `defaultProject` is the project this dependency was defined in
  public init(_ string: String, artifact: LibraryArtifactType? = nil, defaultProject: ProjectRef, context: borrowing Beaver) async throws {
    self.artifact = artifact
    let components = string.split(separator: ":")
    switch (components.count) {
      case 0:
        throw ParsingError.unexpectedNoComponents
      case 1:
        self.name = string
        self.project = defaultProject
      case 2:
        self.name = String(components[1])
        guard let projectRef = await context.getProjectRef(byName: String(components[0])) else {
          throw ParsingError.unknownProject(String(components[0]))
        }
        self.project = projectRef
      default:
        throw ParsingError.malformed(string)
    }
  }
}
