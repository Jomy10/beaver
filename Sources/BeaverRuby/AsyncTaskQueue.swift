import Foundation

/// A Task queue which executes tasks asynchronously
public final class AsyncTaskQueue: @unchecked Sendable {
  private var lock: NSLock = NSLock()
  //private var taskFunctions: [@Sendable () async throws -> ()] = []
  private var tasks: [Task<Void, any Error>] = []

  public func addTask(_ task: @escaping @Sendable () async throws -> ()) {
    self.lock.withLock {
      self.tasks.append(Task(priority: .userInitiated, operation: task))
    }
  }

  /// Wait until all tasks are finished
  public func wait() async throws {
    var c = self.lock.withLock { self.tasks.count }
    while c != 0 {
      var tasks = self.lock.withLock {
        let t = self.tasks
        self.tasks.removeAll()
        return t
      }
      while let task = tasks.popLast() {
        try await task.value
      }
      c = self.lock.withLock { self.tasks.count }
    }
  }
}
