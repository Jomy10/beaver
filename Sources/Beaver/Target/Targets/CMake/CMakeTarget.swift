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
    //let artifactFile = self.artifactURL(projectBuildDir: context.buildDir(for: project.name), artifact: self.artifacts.first!)!
    //stmts.addPhonyCommand(
    //  name: "\(project.name)$:\(self.name)",
    //  command: artifactFile.ninjaPath
    //)
    return stmts
  }
  //public func build(
  //  projectBaseDir: borrowing URL,
  //  projectBuildDir: borrowing URL,
  //  context: borrowing Beaver
  //) async throws {
  //  try await Tools.exec(
  //    Tools.make!,
  //    ["-j", "4", self.name],
  //    baseDir: projectBuildDir,
  //    context: self.name
  //  )
  //}

  //public func build(
  //  artifact: ArtifactType,
  //  projectBaseDir: borrowing URL,
  //  projectBuildDir: borrowing URL,
  //  context: borrowing Beaver
  //) async throws {
  //  try await Tools.exec(
  //    Tools.make!,
  //    ["-j", "4", self.name],
  //    baseDir: projectBuildDir,
  //    context: self.name
  //  )
  //}

  //public func clean(projectBuildDir: borrowing URL, context: borrowing Beaver) async throws {
  //  for artifact in self.artifacts {
  //    let artifactURL = self.artifactURL(projectBuildDir: projectBuildDir, artifact: artifact)!
  //    if FileManager.default.exists(at: artifactURL) {
  //      try FileManager.default.removeItem(at: copy artifactURL)
  //    }
  //  }
  //}

  //public func debugString(_ opts: DebugTargetOptions) -> String {
  //  var str = """
  //  \(self.name)
  //  """

  //  //if opts.flags {
  //  //  str += "\n  cflags: \(self.extraCFlags)"
  //  //  str += "\n  linkerFlags: \(self.extraLinkerFlags)"
  //  //  str += "\n  headers: \(self.headers)"
  //  //}

  //  str += "\n  artifacts: \(self.artifacts)"

  //  return str
  //}
}
