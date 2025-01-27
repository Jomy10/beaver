import Beaver
import ColorizeSwift

struct ListError: Error {
  let message: String

  init(_ message: String) {
    self.message = message
  }
}

extension BeaverCLI {
  mutating func list(context: borrowing Beaver) async throws {
    let project = self.takeArgument()
    let (_, leftover) = self.getArguments()
    let listTargets = leftover.contains("--targets")

    if let project = project {
      guard let projectIndex = await context.projectRef(name: project) else {
        throw ListError("No project named \(project) found")
      }
      await context.withProject(projectIndex) { (project: borrowing AnyProject) in
        print("\(project.name)")
        for targetName in await project.targetNames() {
          print(" \(targetName)")
        }
      }
    } else {
      await context.loopProjects { project in
        let projectName = if project.id == context.currentProjectIndex! {
          project.name.green()
        } else {
          project.name
        }
        print(projectName)
        if listTargets {
          for targetName in await project.targetNames() {
            print(" \(targetName)")
          }
        }
      }
    }
  }
}
