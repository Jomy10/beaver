import Foundation
import Beaver
import RubyGateway
import Utils

extension Project {
  init(
    _ args: borrowing [String: RbObject],
    context: borrowing Beaver
  ) throws {
    let name: String = try args["name"]!.convert()
    let baseDirArg = args["baseDir"]!
    let baseDir: URL = baseDirArg.isNil ? URL.currentDirectory() : URL(filePath: try baseDirArg.convert(to: String.self))
    let buildDirArg = args["buildDir"]!
    let buildDir: URL = buildDirArg.isNil ? URL.currentDirectory().appending(path: ".build") : URL(filePath: try buildDirArg.convert(to: String.self))

    self = Self.init(
      name: name,
      baseDir: baseDir,
      buildDir: buildDir,
      context: context
    )
  }
}

// TODO: also allow shorthand Library("name")
func loadProjectMethod(in module: RbObject, queue: SyncTaskQueue, context: UnsafeSendable<Rc<Beaver>>) throws {
  try module.defineMethod(
    "Project",
    argsSpec: RbMethodArgsSpec(
      mandatoryKeywords: Set(["name"]),
      optionalKeywordValues: [
        "baseDir": URL.currentDirectory(),
        "buildDir": URL.currentDirectory().appending(path: ".build")
      ]
    ),
    body: { (obj: RbObject, method: RbMethod) throws -> RbObject in
      let proj = UnsafeSendable(Rc(try context.value.withInner { (context: borrowing Beaver) in
        try Project(method.args.keyword, context: context)
      }))
      queue.addTask { [proj = consume proj] in
        await context.value.withInner { (context: inout Beaver) in
          _ = await context.addProject(proj.value.take()!)
        }
      }
      return RbObject.nilObject
    }
  )
}
