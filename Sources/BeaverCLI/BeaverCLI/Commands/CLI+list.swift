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
    //let debug = leftover.contains("--debug")
    //var debugOpts = DebugTargetOptions()
    //debugOpts.flags = leftover.contains("--debug-flags")

    if let project = project {
      guard let projectIndex = await context.projectRef(name: project) else {
        throw ListError("No project named \(project) found")
      }
      await context.withProject(projectIndex) { (project: borrowing AnyProject) in
        print("\(project.name)")
        await Self.listTargets(project: project)
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
          await Self.listTargets(project: project)
        }
      }
    }
  }

  private static func listTargets(project: borrowing AnyProject) async {
    for targetName in await project.targetNames() {
      print(" \(targetName)")
    }
  }
}
