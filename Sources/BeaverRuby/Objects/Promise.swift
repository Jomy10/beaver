import RubyGateway
import Atomics

final class RbPromise<T: RbObjectConvertible>: RbObjectConvertible, @unchecked Sendable {
  var fulfilled: ManagedAtomic<Bool>
  var storage: T?
  var error: (any Error)?

  init() {
    self.fulfilled = ManagedAtomic(false)
    self.storage = nil
    self.error = nil
  }

  var value: T {
    get throws {
      guard let storage = self.storage else {
        throw RbException(message: "\(self.error!)")
      }
      return storage
    }
  }

  static var typeName: String {
    "Promise\(T.self)"
  }

  static func load(in module: RbObject) throws {
    let klass = try Ruby.defineClass(Self.typeName, under: module)
    try klass.defineMethod(
      "fulfilled?",
      argsSpec: RbMethodArgsSpec(),
      body: { object, method in
        return RbObject(try Self.fromRbObject(object).fulfilled.load(ordering: .relaxed))
      }
    )
    try klass.defineMethod(
      "value",
      argsSpec: RbMethodArgsSpec(),
      body: { object, method in
        let obj = try Self.fromRbObject(object)
        //guard let val = obj.storage else { return RbObject.nilObject }
        return RbObject(try obj.value)
      }
    )
    try klass.defineMethod(
      "release",
      argsSpec: RbMethodArgsSpec(),
      body: { object, method in
        Self.release(rbObject: object)
        return RbObject.nilObject
      }
    )
  }

  private static func unmanaged(fromRbObject obj: RbObject) -> Unmanaged<RbPromise>? {
    guard let intVal = try? obj.getInstanceVar("@ptr") else { return nil }
    guard let ptrVal = try? intVal.convert(to: Int.self) else { return nil }
    guard let optr = OpaquePointer(bitPattern: ptrVal) else { return nil }
    let ptr = UnsafeMutableRawPointer(optr)
    let unmanaged: Unmanaged<RbPromise> = Unmanaged.fromOpaque(ptr)
    return unmanaged
  }

  static func fromRbObject(_ obj: RbObject) throws -> RbPromise {
    guard let unmanaged = Self.unmanaged(fromRbObject: obj) else {
      throw RbException(message: "Cannot convert \(obj) to \(Self.self)")
    }
    _ = unmanaged.retain()
    return unmanaged.takeRetainedValue()
  }

  init?(_ obj: RbObject) {
    fatalError("Use fromRbObject")
    //guard let unmanaged = Self.unmanaged(fromRbObject: obj) else { return nil }
  }

  var rubyObject: RbObject {
    let unmanaged = Unmanaged.passRetained(self)
    let ptr = unmanaged.toOpaque()
    let ptrPat = Int(bitPattern: ptr)
    let instance = RbObject(ofClass: Self.typeName)!
    try! instance.setInstanceVar("@ptr", newValue: ptrPat)
    return instance
  }

  func resolve(_ obj: consuming T) {
    self.storage = obj
    self.fulfilled.store(true, ordering: .relaxed)
  }

  func fail(_ error: any Error) {
    self.error = error
    self.fulfilled.store(true, ordering: .relaxed)
  }

  static func release(rbObject: RbObject) {
    guard let unmanaged = Self.unmanaged(fromRbObject: rbObject) else { return }
    unmanaged.release()
  }
}
