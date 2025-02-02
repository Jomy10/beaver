import Foundation
//#if DEBUG
//import Utils
//#endif

/// A Task queue which executes tasks synchronously
public final class SyncTaskQueue: @unchecked Sendable {
  private var lock: NSLock = NSLock()
  private var taskFunctions: [@Sendable () async throws -> ()] = []
  private var running = false
  private var currentTaskIndex = -1
  private var currentTask: Task<(), any Error>? = nil
  private var followupTask: Task<(), any Error>? = nil
  private var canFinish = false
  private var finished = false
  private let onError: ((any Error) async -> Void)?

  init(onError: ((any Error) async -> Void)? = nil) {
    self.onError = onError
  }

  public func resume() {
    if !self.finished || self.running {
      fatalError("Attempted to resume queue when not finished or while still running (bug)")
    }
    self.finished = false
    self.canFinish = false
    self.currentTask = nil
    self.followupTask = nil
    self.currentTaskIndex = -1
    self.taskFunctions = []
  }

  public func addTask(_ task: @escaping @Sendable () async throws -> ()) {
    if self.finished {
      //#if DEBUG
      //print(CallStackFormatter.symbols())
      //#endif
      //print(self)
      fatalError("Attempted to add task to SyncTaskQueue after finish (bug)")
    }
    self.lock.withLock {
      self.taskFunctions.append(task)
      if !self.running {
        self.start()
      }
    }
  }

  private func start() {
    self.running = true
    self.canFinish = false
    self.finished = false
    self.currentTask = Task(priority: .userInitiated, operation: self.taskFunctions[0])
    self.currentTaskIndex = 0
    self.followupTask = Task(priority: .utility) {
      do {
        TASK: while true {
          try await self.currentTask!.value
          self.currentTaskIndex += 1
          while self.currentTaskIndex >= self.taskFunctions.count {
            if self.canFinish { break TASK }
            await Task.yield()
          }
          self.currentTask = Task(priority: .userInitiated, operation: self.taskFunctions[self.currentTaskIndex])
        }
      } catch let error {
        if let onError = self.onError {
          await onError(error)
        }
        throw error
      }
    }
  }

  public func wait() async throws {
    self.canFinish = true
    try await self.followupTask?.value
    self.finished = true
    self.running = false
  }
}

extension SyncTaskQueue: CustomStringConvertible {
  public var description: String {
    """
    SyncTaskQueue(
      queuedTasks: \(self.taskFunctions.count),
      currentTaskIndex: \(self.currentTaskIndex),
      running: \(self.running),
      canFinish: \(self.canFinish),
      finished: \(self.finished)
    )
    """
  }
}
