import Beaver
import Utils
import RubyGateway

class ProjectAccessor {
  let ptr: UnsafeMutablePointer<AnyProject>

  init(to proj: inout AnyProject) {
    let ptr = withUnsafeMutablePointer(to: &proj) { $0 }
  }
}

func loadAccessorMethods(
  in module: RbObject,
  queue: SyncTaskQueue,
  context: UnsafeSendable<Rc<Beaver>>
) throws {
  let projectAcessorClass = try module.defineClass("ProjectAccessor", initializer: ProjectAccessor.init)
  try projectAccessorClass.defineMethod(
    "run",
    argsSpec: RbMethodArgsSpec(
      leadingMandatoryCount: 1,
      supportsSplat: true
    ),
    body: { object, method in
      let executableName: String = try method.args.mandatory[0].convert()
      let args: [String] = try method.args.splatted.convert()
      let projectAccessor: ProjectAccessor = try object.convert()

      queue.addTask {
        let targetIndex = await projectAccessor.ptr.pointee.targetIndex(name: executableName)
        try await projectAccessor.ptr.pointee.withExecutable(targetIndex) { (exe: borrowing AnyExecutable) in
          try await executable.run(args: args)
        }
      }
    }
  )

  try module.defineMethod(
    "project",
    argsSpec: RbMethodArgsSpec(
      leadingMandatoryCount: 1,
      requiresBlock: true
    ),
    body: { obj, method in
      let targetName = try method.args.mandatory[0].convert(to: String.self)
      let callback = try method.captureBlock()

      queue.addTask {
        try await context.value.withInner { (ctx: inout Beaver) in
          try await ctx.withProject { (project: inout AnyProject) in
            let projectAccessor = ProjectAccessor(to: &project)
            try await MainActor.run {
              _ = try await callback.call("call", args: [projectAccessor])
            }
          }
        }
      }

      // TODO: return Concurrent::Future
      return RbObject.nilObject
    }
  )
}
