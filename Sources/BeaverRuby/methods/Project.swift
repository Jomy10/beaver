import Foundation
import Beaver
import RubyGateway
import Utils

extension BeaverProject {
  init(
    _ args: borrowing [String: RbObject],
    context: inout Beaver
  ) throws {
    let name: String = try args["name"]!.convert()
    let baseDirArg = args["baseDir"]!
    let baseDir: URL = baseDirArg.isNil ? URL.currentDirectory() : URL(filePath: try baseDirArg.convert(to: String.self))
    //let buildDirArg = args["buildDir"]!
    //let buildDir: URL = buildDirArg.isNil ? context.buildDir(for: name) : URL(filePath: try buildDirArg.convert(to: String.self))

    self = try Self.init(
      name: name,
      baseDir: baseDir,
      //buildDir: buildDir,
      context: &context
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
        //"buildDir": URL.currentDirectory().appending(path: ".build")
      ]
    ),
    body: { (obj: RbObject, method: RbMethod) throws -> RbObject in
      let proj: UnsafeSendable<Rc<BeaverProject>> = UnsafeSendable(Rc(try context.value.withInner { (context: inout Beaver) in
        try BeaverProject(method.args.keyword, context: &context)
      }))
      queue.addTask { [proj = consume proj] in
        await context.value.withInner { (context: inout Beaver) in
          _ = await context.addProject(.beaver(proj.value.take()!))
        }
      }
      return RbObject.nilObject
    }
  )

  try module.defineMethod(
    "importCMake",
    argsSpec: RbMethodArgsSpec(
      leadingMandatoryCount: 1,
      optionalValues: [RbObject.nilObject]
    ),
    body: { (obj, method) in
      let basePath = try method.args.mandatory[0].convert(to: String.self)
      let baseDir = URL(filePath: basePath)
      let buildDirArg = method.args.optional.first!
      let buildDir = buildDirArg.isNil ? context.value.withInner { (ctx: borrowing Beaver) in ctx.buildDir(for: basePath) } : URL(filePath: try buildDirArg.convert(to: String.self))
      queue.addTask {
        try await context.value.withInner { (context: inout Beaver) in
          try await CMakeImporter.import(
            baseDir: baseDir,
            buildDir: buildDir,
            context: &context
          )
        }
      }
      return RbObject.nilObject
    }
  )
}
