import Beaver
import Utils
import RubyGateway
import Atomics

func loadAccessorMethods(
  in module: RbObject,
  queue: SyncTaskQueue,
  context: UnsafeSendable<Rc<Beaver>>
) throws {
  try ProjectAccessor.load(in: module, queue: queue)
  try RbSignalOneshot.load(in: module)

  //let projectAccessorClass = try module.defineClass("ProjectAccessor", initializer: ProjectAccessor.init)
  try module.defineMethod(
    "projectAsync",
    argsSpec: RbMethodArgsSpec(
      leadingMandatoryCount: 1
      //requiresBlock: true
    ),
    body: { obj, method in
      let projectName = try method.args.mandatory[0].convert(to: String.self)
      let promise = RbPromise<ProjectAccessor>()

      queue.addTask {
        do {
          try await context.value.withInner { (ctx: inout Beaver) in
            guard let projectIndex = await ctx.projectRef(name: projectName) else {
              throw ProjectAccessError.noProject(named: projectName)
            }
            let ctxPtr = withUnsafePointer(to: ctx) { $0 }
            await ctx.withProject(projectIndex) { (project: inout AnyProject) in
              let projectAccessor = ProjectAccessor(to: &project, context: ctxPtr.pointee)
              promise.resolve(projectAccessor)
            }
          }
        } catch let error {
          promise.fail(error)
        }
      }

      return RbObject(promise)
    }
  )
}
