import RubyGateway
import Beaver
import Utils

func loadDependencyMethods(in module: RbObject, queue: SyncTaskQueue, context: UnsafeSendable<Rc<Beaver>>) throws {
  try module.defineMethod(
    "pkgconfig",
    argsSpec: RbMethodArgsSpec(
      leadingMandatoryCount: 1
    ),
    body: { (obj, method) in
      let name: String = try method.args.mandatory[0].convert()
      let id = DependencyFuture.registered.count
      DependencyFuture.registered.append(DependencyFuture.Data.pkgconfig(name: name))
      return RbObject(id)
    }
  )
}
