import Beaver
import Foundation
import Tree
import Semaphore
import ProgressIndicators
import ProgressIndicatorsFFI
import BeaverRuby
import Utils
import RubyGateway

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

    ///////////

    //var mutCtx = try Beaver()
    //await mutCtx.addProject(Project(
    //  name: "Libraries",
    //  baseDir: URL(filePath: "Tests/BeaverTests/resources/multiProject/Libraries"),
    //  buildDir: URL(filePath: ".build/tests/multiProject/Libraries"),
    //  context: mutCtx
    //))
    //try await mutCtx.withCurrentProject { @Sendable (proj: inout Project) in
    //  await proj.addTarget(try CLibrary(
    //    name: "Logger",
    //    description: "Logging implementation",
    //    artifacts: [.staticlib],
    //    sources: ["Logger/logger.c"],
    //    headers: Headers(public: [proj.baseDir.appending(path: "Logger")])
    //  ))

    //  await proj.addTarget(try CLibrary(
    //    name: "CXXVec",
    //    description: "C API to vector of C++ standard library",
    //    language: .cxx,
    //    artifacts: [.staticlib],
    //    sources: ["CXXVec/*.cpp"],
    //    headers: Headers(public: [proj.baseDir.appending(path: "CXXVec")])
    //  ))
    //}

    //await mutCtx.addProject(Project(
    //  name: "Main",
    //  baseDir: URL(filePath: "Tests/BeaverTests/resources/multiProject/Main"),
    //  buildDir: URL(filePath: ".build/tests/multiProject/Main"),
    //  context: mutCtx
    //))
    //let loggerDep = try await mutCtx.dependency("Libraries:Logger")
    //let cxxvecDep = try await mutCtx.dependency("Libraries:CXXVec")
    //try await mutCtx.withCurrentProject { @Sendable (proj: inout Project) in
    //  _ = await proj.addTarget(try CExecutable(
    //    name: "Main",
    //    sources: "*.c",
    //    dependencies: [loggerDep, cxxvecDep]
    //  ))
    //}
    //try mutCtx.finalize()

    //let ctx = consume mutCtx
    //try await ctx.build(targetName: "Main")
    //try await ctx.clean()

    let _context = UnsafeSendable(Rc(try Beaver()))
    let queue = try executeRuby(
      scriptFile: URL(filePath: "test.rb"),
      context: _context
    )
    try await queue.wait()
    let context = _context.value.take()!
    print(await context.debugString)
  }
}
