import Foundation
import Beaver
import RubyGateway
import Utils

extension BeaverProject {
  init(
    _ args: borrowing [String: RbObject],
    context: Beaver
  ) throws {
    let name: String = try args["name"]!.convert()
    let baseDirArg = args["baseDir"]!
    let baseDir: URL = baseDirArg.isNil ? URL.currentDirectory() : URL(filePath: try baseDirArg.convert(to: String.self))

    self = try Self.init(
      name: name,
      baseDir: baseDir,
      context: context
    )
  }
}

// TODO: also allow shorthand Library("name")
func loadProjectMethod(in module: RbObject, queue: SyncTaskQueue, context: Beaver) throws {
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
      let proj: UnsafeSendable<Rc<BeaverProject>> = UnsafeSendable(Rc(try BeaverProject(method.args.keyword, context: context)))
      queue.addTask { [proj = consume proj] in
        await context.addProject(.beaver(proj.value.take()!))
      }
      return RbObject.nilObject
    }
  )

  try module.defineMethod(
    "importCMake",
    argsSpec: RbMethodArgsSpec(
      leadingMandatoryCount: 1,
      optionalKeywordValues: [
        "cmakeFlags": [String](),
        "makeFlags": [String]()
      ]
    ),
    body: { (obj, method) in
      let basePath = try method.args.mandatory[0].convert(to: String.self)
      let baseDir = URL(filePath: basePath)
      let buildDir = context.buildDir(for: basePath)
      let cmakeFlags = try method.args.keyword["cmakeFlags"]!.convert(to: [String].self)
      let makeFlags = try method.args.keyword["makeFlags"]!.convert(to: [String].self)
      queue.addTask {
        try await CMakeImporter.import(
          baseDir: baseDir,
          buildDir: buildDir,
          cmakeFlags: cmakeFlags,
          makeFlags: makeFlags,
          context: context
        )
      }
      return RbObject.nilObject
    }
  )
}
