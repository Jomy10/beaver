import Foundation

public protocol Library: Target where ArtifactType == LibraryArtifactType {
  /// Flags to use when linking to this library.
  ///
  /// When linking a program, all linkerflags of all dependencies should be used
  func linkerFlags() async throws -> [String] // TODO: deprecate?
  /// Simple -l flag to use when linking to this library. Not including additional linker flags
  func linkFlag() -> String
  /// Flags to be used by the direct dependants of this library
  func publicCflags() async throws -> [String]
  /// Header include directories to be used by the direct dependants of this library
  func publicHeaders(baseDir: URL) async throws -> [URL]
  /// The output directory where all artifacts are stored
  func artifactOutputDir(projectBuildDir: URL, forArtifact artifact: LibraryArtifactType?) async throws -> URL
}

extension Library {
  public func linkFlag() -> String {
    "-l\(self.name)"
  }
}

@available(*, deprecated, message: "Use Dependency instead")
public struct LibraryRef: Sendable, Hashable {
  /// The name of the library
  let name: String
  /// The project this library belongs to
  let project: ProjectRef
  /// The artifact to link against
  let artifact: LibraryArtifactType

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
  public init(_ string: String, artifact: LibraryArtifactType = .staticlib, defaultProject: ProjectRef, context: borrowing Beaver) async throws {
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
