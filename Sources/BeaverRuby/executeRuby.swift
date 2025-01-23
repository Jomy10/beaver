import Foundation
import Beaver
import RubyGateway
import Utils
import AsyncAlgorithms
import Atomics

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
  let queue: SyncTaskQueue = SyncTaskQueue()

  // Lock is probably not needed
  let slice = try RWLock(MutableDiscontiguousSlice(args))

  let beaverModule = try Ruby.defineModule("Beaver")

  try loadCommandLineMethods(in: beaverModule, args: slice, queue: queue, context: context)
  try loadProjectMethod(in: beaverModule, queue: queue, context: context)
  try loadCMethods(in: beaverModule, queue: queue, context: context)
  try loadDependencyMethods(in: beaverModule, queue: queue, context: context)
  try loadUtilsMethods(in: beaverModule, queue: queue, context: context)

  let libFilePath = Bundle.module.path(forResource: "lib", ofType: "rb", inDirectory: "lib")!
  try Ruby.require(filename: libFilePath)
  try Ruby.eval(ruby: scriptContents)
  return queue
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
