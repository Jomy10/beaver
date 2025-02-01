import Foundation

/// A Task queue which executes tasks synchronously
public final class SyncTaskQueue: @unchecked Sendable {
  private var lock: NSLock = NSLock()
  private var taskFunctions: [@Sendable () async throws -> ()] = []
  private var running = false
  private var currentTaskIndex = -1
  private var currentTask: Task<(), any Error>? = nil
  private var followupTask: Task<(), any Error>? = nil
  private var finished = false
  private let onError: ((any Error) async -> Void)?

  init(onError: ((any Error) async -> Void)? = nil) {
    self.onError = onError
  }

  public func addTask(_ task: @escaping @Sendable () async throws -> ()) {
    self.lock.withLock {
      self.taskFunctions.append(task)
      if !self.running {
        self.start()
      }
    }
  }

  private func start() {
    self.running = true
    self.currentTask = Task(priority: .userInitiated, operation: self.taskFunctions[0])
    self.currentTaskIndex = 0
    self.followupTask = Task(priority: .utility) {
      do {
        TASK: while true {
          try await self.currentTask!.value
          self.currentTaskIndex += 1
          while self.currentTaskIndex >= self.taskFunctions.count {
            if self.finished { break TASK }
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
    self.finished = true
    try await self.followupTask?.value
  }
}
