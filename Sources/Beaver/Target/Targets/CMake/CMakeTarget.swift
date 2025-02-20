import Foundation
import Utils

public protocol CMakeTarget: Target, ~Copyable, Sendable {
  var cmakeId: String { get }
}

extension CMakeTarget where Self: ~Copyable {
  public func artifactOutputDir(projectBuildDir: borrowing URL, artifact: ArtifactType) -> URL? {
    return copy projectBuildDir
  }

  public func buildStatements<P: Project & ~Copyable>(inProject project: borrowing P, context: borrowing Beaver) async throws -> BuildBackendBuilder {
    var stmts = BuildBackendBuilder()
    stmts.addNinjaCommand(
      name: "\(project.name)$:\(self.name)",
      baseDir: context.buildDir(for: project.name),
      filename: "build.ninja",
      targets: [self.name]
    )
    stmts.addPhonyCommand(
      name: "\(project.name)$:\(self.name)$:\(self.artifacts.first!)",
      commands: ["\(project.name)$:\(self.name)"]
    )
    return stmts
  }
}
