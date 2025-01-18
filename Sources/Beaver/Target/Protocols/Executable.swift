import Foundation

public protocol Executable: Target where ArtifactType == ExecutableArtifactType {
  //struct RunError: Error {
  //  let target: TargetRef
  //  let reason: Reason

  //  enum Reason {
  //    case noExecutable
  //  }
  //}
}

extension Executable {
  public func run(projectBuildDir: URL, args: [String]) async throws {
    guard let url = self.artifactURL(projectBuildDir: projectBuildDir, artifact: .executable) else {
      throw ExecutableRunError(self, .noExecutable)
    }

    try Tools.exec(url, args)
  }
}
