import Foundation
import Beaver
import RubyGateway
import Utils
import AsyncAlgorithms
import Atomics
//import RubyRaise

/// Errors for the ruby command line utility (e.g. `cmd`, `opt`, `arg`)
enum CommandLineError: Error {
  /// Expected arguments for function `opt` or `arg`
  case noArgs
}

/// Initializes ruby environment and executes the given script file
public func executeRuby<Args: Collection & BidirectionalCollection & Sendable>(
  scriptFile: URL,
  args: Args,
  context: UnsafeSendable<Rc<Beaver>>
) throws -> SyncTaskQueue
  where Args.Element == String
{
  let scriptContents = try String(contentsOf: scriptFile, encoding: .utf8)

  let queueError = UnsafeSharedBox(ManagedAtomic(false))
  let queue: SyncTaskQueue = SyncTaskQueue(onError: { _ in
    queueError.value.store(true, ordering: .relaxed)
  })

  // Lock is probably not needed
  let slice = try RWLock(MutableDiscontiguousSlice(args))

  let beaverModule = try Ruby.defineModule("Beaver")

  try Ruby.defineGlobalVar(
    "$BEAVER_ERROR",
    get: {
      //RubyQueue.global.submitSync {
        queueError.value.load(ordering: .relaxed)
      //}
    },
    set: { (val: Bool) in
      //RubyQueue.queue.sync {
        queueError.value.store(val, ordering: .relaxed)
      //}
    }
  )
  try loadCommandLineMethods(in: beaverModule, args: slice, queue: queue, context: context)
  try loadProjectMethod(in: beaverModule, queue: queue, context: context)
  try loadCMethods(in: beaverModule, queue: queue, context: context)
  try loadDependencyMethods(in: beaverModule, queue: queue, context: context)
  try loadUtilsMethods(in: beaverModule, queue: queue, context: context)
  try loadAccessorMethods(in: beaverModule, queue: queue, context: context)

  let libFilePath = Bundle.module.path(forResource: "lib", ofType: "rb", inDirectory: "lib")!
  try Ruby.require(filename: libFilePath)
  do {
    try Ruby.eval(ruby: scriptContents)
  } catch let error as RbError {
    if case .rubyException(let exc) = error {
      // If the exception is a system exit, then we check the status, otherwise just throw the error
      guard (try exc.exception.call("is_a?", args: [Ruby.get("SystemExit")]).convert(to: Bool.self)) else {
        throw error
      }
      guard (try exc.exception.call("status").convert(to: Int.self)) == 300 else {
        throw error
      }
      // The exception is an exit with return code 300. We designated this return code
      // to indicate an error in the queue, so we ignore the error here and let the
      // queue throw an error
    } else {
      throw error
    }
  } catch let error {
    throw error
  }

  return queue
}

public func deallocateRubyObjects() {
  //Promise.deallocateAll()
}

enum RbConversionError: Error, @unchecked Sendable {
  case incompatible(from: RbType, to: Any.Type)
  case unexpectedType(got: RbType, expected: [RbType])
  /// An unexpected key was found in a hash
  case unexpectedKey(key: String, type: Any.Type)
  /// Expected a key in a hash to be present, but did not find the key
  case keyNotFound(key: String, type: Any.Type)
  case unknownError
}
