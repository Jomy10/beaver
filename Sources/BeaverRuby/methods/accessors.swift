import Beaver
import Utils
import RubyGateway
import Atomics

func loadAccessorMethods(
  in module: RbObject,
  queue: SyncTaskQueue,
  context: Beaver
) throws {
  try ProjectAccessor.load(in: module, queue: queue)

  //let projectAccessorClass = try module.defineClass("ProjectAccessor", initializer: ProjectAccessor.init)
  try module.defineMethod(
    "_projectAsyncSync",
    argsSpec: RbMethodArgsSpec(
      leadingMandatoryCount: 1
      //requiresBlock: true
    ),
    body: { obj, method in
      let projectName = try method.args.mandatory[0].convert(to: String.self)
      let promise = RbPromise()

      queue.addTask {
        do {
          guard let projectIndex = await context.projectRef(name: projectName) else {
            throw ProjectAccessError.noProject(named: projectName)
          }
          await context.withProject(projectIndex) { (project: inout AnyProject) in
            let projectAccessor = ProjectAccessor(to: &project, context: context)
            promise.resolve(RbObject(projectAccessor))
          }
        } catch let error {
          promise.fail(error)
        }
      }

      return RbObject(promise)
    }
  )
}
