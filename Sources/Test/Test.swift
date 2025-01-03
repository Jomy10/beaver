import Beaver
import Foundation
import Tree
import Semaphore
import ProgressIndicators
import ProgressIndicatorsFFI

//extension Tree.Node: @retroactive CustomStringConvertible {
//  public var description: String {
//    var string = "\(self.element)\n"
//    for node in self.children {
//      string += node.description.split(separator: "\n").map { "  \($0)" }.joined(separator: "\n")
//    }
//    return string
//  }
//}
extension String: @retroactive Identifiable {
  public var id: Self {
    self
  }
}

@main
struct Test {
  static func main() async throws {
    //let root = Node("1")
    //let a = Node("2")
    //root.append(child: a)
    //let b = Node("3")
    //root.append(child: b)
    //a.append(child: Node("4"))
    //let c = Node("5")
    //a.append(child: c)
    //b.append(child: c)
    //b.append(child: Node("6"))
    //c.append(child: Node("4"))

    //print(root)

    //var dependencyArray: [String] = []
    //for child in root.breadthFirst.reversed() {
    //  if !dependencyArray.contains(child.element) {
    //    dependencyArray.append(child.element)
    //  }
    //}
    //print(dependencyArray)

    //let semaphore = AsyncSemaphore(value: 1)

    //await semaphore.wait()
    //print(semaphore)
    //await semaphore.wait()
    //print(semaphore)

    ///////

    var mutCtx = Beaver()
    await mutCtx.addProject(Project(
      name: "Logger",
      baseDir: URL(filePath: "Tests/BeaverTests/resources/multiProject/Logger"),
      buildDir: URL(filePath: ".build/tests/multiProject/Logger")
    ))
    try await mutCtx.withCurrentProject { (proj: inout Project) in
      await proj.addTarget(CLibrary(
        name: "Logger",
        description: "Logging implementation",
        artifacts: [.staticlib, .dynlib],
        sources: ["logger.c"],
        headers: Headers(public: [proj.baseDir])
      ))
    }

    await mutCtx.addProject(Project(
      name: "Main",
      baseDir: URL(filePath: "Tests/BeaverTests/resources/multiProject/Main"),
      buildDir: URL(filePath: ".build/tests/multiProject/Main")
    ))
    let loggerDep: LibraryRef = try await LibraryRef("Logger:Logger", defaultProject: mutCtx.currentProjectIndex!, context: mutCtx)
    try await mutCtx.withCurrentProject { (proj: inout Project) in
      await proj.addTarget(CExecutable(
        name: "Main",
        sources: "*.c",
        dependencies: [loggerDep]
      ))
    }

    let ctx = consume mutCtx
    try await ctx.build("Main")

    ///////////

  }
}
