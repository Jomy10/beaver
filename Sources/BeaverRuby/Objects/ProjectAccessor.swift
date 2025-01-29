import RubyGateway
import Beaver
import Utils

struct ProjectAccessor: RbObjectConvertible, @unchecked Sendable {
  let ptr: UnsafeMutablePointer<AnyProject>
  let context: UnsafePointer<Beaver>

  init(to proj: inout AnyProject, context: borrowing Beaver) {
    self.ptr = withUnsafeMutablePointer(to: &proj) { $0 }
    self.context = withUnsafePointer(to: context) { $0 }
  }

  init?(_ obj: RbObject) {
    guard let ptrVal = try? obj.getInstanceVar("@ptr") else { return nil }
    guard let ctxPtrVal = try? obj.getInstanceVar("@ctxPtr") else { return nil }
    guard let ptrInt = try? ptrVal.convert(to: Int.self) else { return nil }
    guard let ctxPtrInt = try? ctxPtrVal.convert(to: Int.self) else { return nil }
    guard let opPtr = OpaquePointer(bitPattern: ptrInt) else { return nil }
    guard let ctxPtr = OpaquePointer(bitPattern: ctxPtrInt) else { return nil }
    self.ptr = UnsafeMutableRawPointer(opPtr).assumingMemoryBound(to: AnyProject.self)
    self.context = UnsafeRawPointer(ctxPtr).assumingMemoryBound(to: Beaver.self)
  }

  var rubyObject: RbObject {
    let instance = RbObject(ofClass: "ProjectAccessor")!
    try! instance.setInstanceVar("@ptr", newValue: Int(bitPattern: self.ptr))
    try! instance.setInstanceVar("@ctxPtr", newValue: Int(bitPattern: self.context))
    return instance
  }

  static func load(in module: RbObject, queue: SyncTaskQueue) throws {
    try RbPromise<ProjectAccessor>.load(in: module)

    let klass = try Ruby.defineClass("ProjectAccessor", under: module)
    try klass.defineMethod(
      "runAsync",
      argsSpec: RbMethodArgsSpec(
        leadingMandatoryCount: 1,
        supportsSplat: true
      ),
      body: { object, method in
        let executableName: String = try method.args.mandatory[0].convert()
        let args: [String] = try method.args.splatted.map { try $0.convert(to: String.self) }
        let projectAccessor: ProjectAccessor = try object.convert()
        let signal = RbSignalOneshot()

        // TODO: error handling
        queue.addTask {
          do {
            guard let targetIndex = await projectAccessor.ptr.pointee.targetIndex(name: executableName) else {
              throw TargetAccessError.noTarget(named: executableName)
            }
            try await projectAccessor.ptr.pointee.withExecutable(targetIndex) { (exe: borrowing AnyExecutable) in
              try await exe.run(projectBuildDir: projectAccessor.ptr.pointee.buildDir, args: args)
              signal.complete()
            }
          } catch let error {
            signal.fail(error)
          }
        }

        return RbObject(signal)
      }
    )

    try klass.defineMethod(
      "buildAsync",
      argsSpec: RbMethodArgsSpec(
        leadingMandatoryCount: 1
      ),
      body: { object, method in
        let targetName: String = try method.args.mandatory[0].convert()
        let projectAccessor: ProjectAccessor = try object.convert()
        let signal = RbSignalOneshot()
        print("start building")

        queue.addTask {
          print("executing task")
          do {
            guard let targetIndex = await projectAccessor.ptr.pointee.targetIndex(name: targetName) else {
              throw TargetAccessError.noTarget(named: targetName)
            }
            try await projectAccessor.ptr.pointee.withTarget(targetIndex) { (target: borrowing AnyTarget) in
              try await target.build(
                projectBaseDir: projectAccessor.ptr.pointee.baseDir,
                projectBuildDir: projectAccessor.ptr.pointee.buildDir,
                context: projectAccessor.context.pointee
              )
            }
            signal.complete()
          } catch let error {
            signal.fail(error)
          }
        }

        return RbObject(signal)
      }
    )
  }
}
