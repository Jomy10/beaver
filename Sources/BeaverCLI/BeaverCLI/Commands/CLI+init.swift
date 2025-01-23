import Foundation
import Utils

extension BeaverCLI {
  func initializeBeaver() throws {
    //let filename = self.takeArgument() ?? "beaver.rb"
    let (_, leftover) = self.getArguments()
    var args = MutableDiscontiguousSlice(leftover)
    let filename = try Self.valueForArgument(["--file", "-f"], in: &args) ?? "beaver.rb"
    let project = try Self.valueForArgument(["--project", "-p"], in: &args)
    let buildDir = try Self.valueForArgument(["--buildDir", "-d"], in: &args)

    let gitignore: String = """
    /\(buildDir ?? ".build")
    """

    let beaverFile = if let project = project {
      """
      Project(name: "\(project)"\(buildDir == nil ? "" : ", buildDir: \"\(buildDir!)\""))

      """
    } else {
      "\n"
    }

    let gitignoreURL = URL(filePath: ".gitignore")
    let beaverURL = URL(filePath: filename)

    if !FileManager.default.exists(at: gitignoreURL) {
      try FileManager.default.createFile(at: gitignoreURL, contents: gitignore)
    } else {
      if !FileManager.default.isReadable(at: gitignoreURL) || !FileManager.default.isWritable(at: gitignoreURL) {
        print("Unsufficient permissions on file \(gitignoreURL.path), nothing will be appended")
      } else {
        let currentGitignore = try String(contentsOf: gitignoreURL, encoding: .utf8)
        let lines = currentGitignore.split(whereSeparator: \.isNewline)
        var newLines = lines
        let tobeLines = gitignore.split(whereSeparator: \.isNewline)
        for tobe in tobeLines {
          if !lines.contains(tobe) {
            newLines.append(tobe)
          }
        }
        try newLines
          .joined(separator: "\n")
          .data(using: .utf8)!
          .write(to: gitignoreURL)
      }
    }

    if !FileManager.default.exists(at: beaverURL) {
      try FileManager.default.createFile(at: beaverURL, contents: beaverFile)
    } else {
      print("Beaver was already initialized in current directory; found \(beaverURL.path)")
    }
  }
}
