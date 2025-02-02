import Foundation
import RubyGateway
import Utils
import Atomics
import WorkQueue

@inline(never)
func __ruby_queue_execute(_ args: UnsafeMutableRawPointer?) {
  let ptr = args!.assumingMemoryBound(to: RubyQueue.WorkFnArgs.self)
  do {
    try ptr.pointee.fn()
  } catch let error {
    ptr.pointee.onError(error)
  }
}

@available(*, deprecated)
public struct RubyQueue {
  @available(*, deprecated)
  public static nonisolated(unsafe) let global = RubyQueue()

  public enum QueueError: Error {
    case failedToPushWork
  }

  let queue: OpaquePointer

  private init() {
    self.queue = workqueue_new()
  }

  struct WorkFnArgs {
    let fn: () throws -> Void
    let onError: (any Error) -> Void
  }

  public func submit(
    _ fn: @escaping () throws -> Void,
    onError: @escaping (any Error) -> Void
  ) throws(QueueError) {
    //print(CallStackFormatter.symbols())
    let ptr = UnsafeMutablePointer<WorkFnArgs>.allocate(capacity: 1)
    ptr.pointee = WorkFnArgs(fn: fn, onError: onError)
    if (!workqueue_push(self.queue, __ruby_queue_execute, UnsafeMutableRawPointer(ptr))) {
      let rawptr = ptr.deinitialize(count: 1)
      rawptr.deallocate()
      throw .failedToPushWork
    }
  }

  public func submit(_ fn: @escaping () -> Void) throws(QueueError) {
    try self.submit(fn, onError: { _ in })
  }

  public func submitSync<Result>(_ fn: @escaping () throws -> Result) async throws -> Result {
    let done = ManagedAtomic(false)
    let err: UnsafeSharedBox<(any Error)?> = UnsafeSharedBox(nil)
    let res: UnsafeSharedBox<Result?> = UnsafeSharedBox(nil)

    try self.submit({
      res.value = try fn()
      done.store(true, ordering: .relaxed)
    }, onError: { error in
      err.value = error
      done.store(true, ordering: .relaxed)
    })

    while !done.load(ordering: .relaxed) {
      await Task.yield()
    }

    if let err = err.value {
      throw err
    }

    return res.value!
  }

  public func join() async {
    let done = ManagedAtomic(false)
    let queuePtr = UnsafeSendable(self.queue)
    Task {
      workqueue_drain(queuePtr.value)
      done.store(true, ordering: .relaxed)
    }
    while !done.load(ordering: .relaxed) {
      await Task.yield()
    }
    workqueue_release(self.queue)
  }
}

//public final class RubyQueue: Thread {
//  public static nonisolated(unsafe) let global = RubyQueue()

//  private var canFinish = ManagedAtomic(false)
//  private var isMainFinished = ManagedAtomic(false)
//  // TODO: use propper queue, maybe a ring buffer?
//  private var taskQueue: RWLock<[(task: () throws -> Void, onError: ((any Error) -> Void))]> = try! RWLock([])

//  public override func main() {
//    while true {
//      var hasMoreIndication = false
//      do {
//        let val = try self.taskQueue.write({ (queue) -> (() throws -> Void, (any Error) -> Void)? in
//          if queue.count == 0 {
//            hasMoreIndication = false
//            return nil
//          }
//          hasMoreIndication = true
//          let (cb, onError) = queue.removeFirst()
//          return (cb, onError)
//        })

//        if let val = val {
//          let (cb, onError) = val
//          do {
//            try cb()
//          } catch let error {
//            onError(error)
//          }
//        }

//        if self.canFinish.load(ordering: .relaxed) {
//          do {
//            if (try self.taskQueue.read { queue in queue.count }) == 0 {
//              break
//            }
//          } catch {
//            MessageHandler.error("Unexpected error from RubyQueue thread: \(error)")
//          }
//        }

//        if hasMoreIndication {
//          Thread.sleep(forTimeInterval: TimeInterval(0.04))
//          //try Task.sleep(for: .microseconds(40))
//        } else {
//          Thread.sleep(forTimeInterval: TimeInterval(0.4))
//          //try .sleep(for: .milliseconds(40))
//        }

//      } catch let error {
//        MessageHandler.error("Unexpected error from RubyQueue thread: \(error)")
//      }
//    }

//    self.isMainFinished.store(true, ordering: .relaxed)
//  }

//  public func join() async {
//    self.canFinish.store(true, ordering: .relaxed)

//    while true {
//      if self.isMainFinished.load(ordering: .relaxed) {
//        break
//      }
//      await Task.yield()
//    }
//  }

//  /// Return a semaphore that is called when the task is ready to be executed
//  //func takeTicket(task: (() throws -> Void)? = nil) -> (start: DispatchSemaphore, end: DispatchSemaphore) {
//  //  self.taskQueue.write { tasks in
//  //    let semaphore = DispatchSemaphore()
//  //    let endSemaphore = DispatchSemaphore()
//  //    var task: (() throws -> Void)? = nil
//  //    tasks.append((start: semaphore, end: endSemaphore, task: task))
//  //    return semaphore
//  //  }
//  //}

//  //enum OnError {
//  //  case cancel
//  //  case continue
//  //}

//  public func submit(
//    _ cb: @escaping () throws -> Void,
//    onError: @escaping (any Error) -> Void
//  ) throws {
//    try self.taskQueue.write { queue in
//      queue.append((task: cb, onError: onError))
//    }
//  }

//  public func submitSync<Result>(
//    _ cb: @escaping () throws -> Result
//  ) async throws -> Result {
//    let val: UnsafeSharedBox<Result?> = UnsafeSharedBox(nil)
//    let err: UnsafeSharedBox<(any Error)?> = UnsafeSharedBox(nil)
//    let signal = ManagedAtomic(false)
//    try self.taskQueue.write { queue in
//      queue.append((
//        task: {
//          val.value = try cb()
//          signal.store(true, ordering: .relaxed)
//        },
//        onError: { error in
//          err.value = error
//        }
//      ))
//    }

//    while !signal.load(ordering: .relaxed) {
//      await Task.yield()
//    }

//    if let err = err.value {
//      throw err
//    }

//    return val.value!
//  }

//  //func sync<Result>(onError: OnError = .continue, _ cb: () throws -> Result) rethrows -> Result {
//  //  let (start, end) = self.takeTicket()
//  //  start.wait()
//  //  do {
//  //    try cb()
//  //  } catch let error {
//  //    if onError == .cancel {
//  //      self.cancel()
//  //    } else {
//  //      end.signal()
//  //    }
//  //    throw error
//  //  }
//  //}

//  //func async(onError: OnError = .continue, _ cb: () throws -> Result) rethrows -> Result {
//  //  self.schedule(cb)
//  //}
//}

//public struct RubyQueue {
//  public static let queue: DispatchQueue = DispatchQueue(
//    label: "BeaverRuby",
//    qos: .userInitiated,
//    attributes: [.concurrent]
//  )
//}

public struct RubyCleanupError: Error {
  let code: Int32
}

public func cleanupRuby() throws(RubyCleanupError) {
  let code = Ruby.cleanup()
  if code != 0 {
    throw RubyCleanupError(code: code)
  }
}

public func setupRuby() {
  _ = Ruby.softSetup()
}
