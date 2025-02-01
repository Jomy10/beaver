import Foundation
import Utils

public protocol Executable: ~Copyable, Target where ArtifactType == ExecutableArtifactType {
  //struct RunError: Error {
  //  let target: TargetRef
  //  let reason: Reason

  //  enum Reason {
  //    case noExecutable
  //  }
  //}
}

extension Executable where Self: ~Copyable {
  public var type: TargetType { .executable }

  public func run(projectBuildDir: URL, args: [String]) async throws {
    guard let url = self.artifactURL(projectBuildDir: projectBuildDir, artifact: .executable) else {
      throw ExecutableRunError(self, .noExecutable)
    }

    try await Tools.exec(url, args)
  }

  public var eArtifacts: [eArtifactType] {
    self.artifacts.map { .executable($0) }
  }
}
