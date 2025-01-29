import RubyGateway
import Atomics

final class RbSignalOneshot: RbObjectConvertible, @unchecked Sendable {
  var signal: ManagedAtomic<Bool>
  var failure: (any Error)? = nil

  init() {
    self.signal = ManagedAtomic(false)
  }

  func complete() {
    self.signal.store(true, ordering: .relaxed)
  }

  func fail(_ err: any Error) {
    self.failure = err
    self.signal.store(true, ordering: .relaxed)
  }

  var finished: Bool {
    return self.signal.load(ordering: .relaxed)
  }

  var failed: Bool {
    self.failure != nil
  }

  private static func unmanaged(fromRbObject obj: RbObject) -> Unmanaged<RbSignalOneshot>? {
    guard let intVal = try? obj.getInstanceVar("@ptr") else { return nil }
    guard let ptrVal = try? intVal.convert(to: Int.self) else { return nil }
    guard let optr = OpaquePointer(bitPattern: ptrVal) else { return nil }
    let ptr = UnsafeMutableRawPointer(optr)
    let unmanaged: Unmanaged<RbSignalOneshot> = Unmanaged.fromOpaque(ptr)
    return unmanaged
  }

  static func load(in module: RbObject) throws {
    let klass = try Ruby.defineClass("SignalOneshot", under: module)
    try klass.defineMethod(
      "finished?",
      argsSpec: RbMethodArgsSpec(),
      body: { object, method in
        //return RbObject(try object.convert(to: RbSignalOneshot.self).finished)
        return RbObject(try Self.fromRubyObject(object).finished)
      }
    )
    try klass.defineMethod(
      "failed?",
      argsSpec: RbMethodArgsSpec(),
      body: { object, method in
        return RbObject(try Self.fromRubyObject(object).failed)
        //return RbObject(try object.convert(to: RbSignalOneshot.self).)
      }
    )
    try klass.defineMethod(
      "check",
      argsSpec: RbMethodArgsSpec(),
      body: { object, method in
        //defer { Self.release(rbObject: object) }
        guard let failure = try Self.fromRubyObject(object).failure else {
          return RbObject.nilObject
        }
        throw RbException(message: "\(failure)")
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

  static func fromRubyObject(_ obj: RbObject) throws -> RbSignalOneshot {
    guard let unmanaged = Self.unmanaged(fromRbObject: obj) else {
      throw RbException(message: "Cannot convert \(obj) to \(Self.self)")
    }
    _ = unmanaged.retain()
    return unmanaged.takeRetainedValue()
  }

  init?(_ obj: RbObject) {
    fatalError("use fromRubyObject")
    //guard let ptrVal = try? obj.convert(to: Int.self) else { return nil }
    //guard let optr = OpaquePointer(bitPattern: ptrVal) else { return nil }
    //let ptr = UnsafeMutableRawPointer(optr)
    //let unmanaged: Unmanaged<RbSignal> = Unmanaged.fromOpaque(ptr)
    //guard let unmanaged = Self.unmanaged(fromRbObject: obj) else { return nil }
    //let v = unmanaged.takeUnretainedValue()
    //self.signal = v.signal
  }

  var rubyObject: RbObject {
    let unmanaged = Unmanaged.passRetained(self)
    let ptr = unmanaged.toOpaque()
    let ptrPat = Int(bitPattern: ptr)
    let instance = RbObject(ofClass: "SignalOneshot")!
    try! instance.setInstanceVar("@ptr", newValue: ptrPat)
    return instance
  }

  static func release(rbObject: RbObject) {
    guard let unmanaged: Unmanaged<RbSignalOneshot> = Self.unmanaged(fromRbObject: rbObject) else { return }
    unmanaged.release()
  }
}

//final class Promise: RbObjectConvertible {
//  var signal: ManagedAtomic<Bool>
//  var allocatedIndex: Int

//  private static var allocated: [Promise] = []

//  init() {
//    self.signal = ManagedAtomic(false)
//    self.allocatedIndex = allocated.count
//    allocated.append(self)
//  }

//  init?(_ obj: RbObject) {
//    guard let index = try? obj.convert(to: Int.self) else { return nil }
//    self = Self.allocated[index]
//  }

//  var rubyObject: RbObject {
//    return RbObject(self.allocatedIndex)
//  }

//  static func deallocateAll() {
//    self.allocated.removeAll()
//  }
//}
