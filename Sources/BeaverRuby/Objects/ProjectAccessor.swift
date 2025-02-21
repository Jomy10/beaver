import RubyGateway
import Beaver
import Utils

struct ProjectAccessor: RbObjectConvertible, @unchecked Sendable {
  let ptr: UnsafeMutablePointer<AnyProject>
  let context: Unmanaged<Beaver>

  init(to proj: inout AnyProject, context: Beaver) {
    self.ptr = withUnsafeMutablePointer(to: &proj) { $0 }
    self.context = Unmanaged.passUnretained(context) //withUnsafePointer(to: context) { $0 }
  }

  init?(_ obj: RbObject) {
    guard let ptrVal = try? obj.getInstanceVar("@ptr") else { return nil }
    guard let ctxPtrVal = try? obj.getInstanceVar("@ctxPtr") else { return nil }
    guard let ptrInt = try? ptrVal.convert(to: Int.self) else { return nil }
    guard let ctxPtrInt = try? ctxPtrVal.convert(to: Int.self) else { return nil }
    guard let opPtr = OpaquePointer(bitPattern: ptrInt) else { return nil }
    guard let ctxPtr = OpaquePointer(bitPattern: ctxPtrInt) else { return nil }
    self.ptr = UnsafeMutableRawPointer(opPtr).assumingMemoryBound(to: AnyProject.self)
    self.context = Unmanaged.fromOpaque(UnsafeRawPointer(ctxPtr))
  }

  var rubyObject: RbObject {
    let instance = RbObject(ofClass: "ProjectAccessor")!
    try! instance.setInstanceVar("@ptr", newValue: Int(bitPattern: self.ptr))
    try! instance.setInstanceVar("@ctxPtr", newValue: Int(bitPattern: self.context.toOpaque()))
    return instance
  }

  static func load(in module: RbObject, queue: SyncTaskQueue) throws {
    let klass = try Ruby.defineClass("ProjectAccessor", under: module)
    try klass.defineMethod(
      "_runAsyncSync",
      argsSpec: RbMethodArgsSpec(
        leadingMandatoryCount: 1,
        supportsSplat: true
      ),
      body: { object, method in
        let executableName: String = try method.args.mandatory[0].convert()
        let args: [String] = try method.args.splatted.map { try $0.convert(to: String.self) }
        let projectAccessor: ProjectAccessor = try object.convert()
        let signal = RbSignalOneshot()

        queue.addTask {
          do {
            guard let targetIndex = await projectAccessor.ptr.pointee.targetIndex(name: executableName) else {
              throw TargetAccessError.noTarget(named: executableName)
            }
            try await projectAccessor.ptr.pointee.run(targetIndex, args: args, context: projectAccessor.context.takeUnretainedValue())
            signal.complete()
          } catch let error {
            signal.fail(error)
          }
        }

        return RbObject(signal)
      }
    )

    try klass.defineMethod(
      "_buildAsyncSync",
      argsSpec: RbMethodArgsSpec(
        leadingMandatoryCount: 1
      ),
      body: { object, method in
        let targetName: String = try method.args.mandatory[0].convert()
        let projectAccessor: ProjectAccessor = try object.convert()
        let signal = RbSignalOneshot()

        queue.addTask {
          do {
            guard let targetIndex = await projectAccessor.ptr.pointee.targetIndex(name: targetName) else {
              throw TargetAccessError.noTarget(named: targetName)
            }

            try await projectAccessor.context.takeUnretainedValue().build(TargetRef(
              target: targetIndex,
              project: projectAccessor.ptr.pointee.id
            ))
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
