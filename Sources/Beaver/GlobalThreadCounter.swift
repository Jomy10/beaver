import Atomics

struct GlobalThreadCounter: Sendable {
  private static nonisolated(unsafe) var processes: ManagedAtomic<Int> = ManagedAtomic(0)
  private static nonisolated(unsafe) var maxProcesses: ManagedAtomic<Int> = ManagedAtomic(1)

  public static func setMaxProcesses(_ newValue: Int) {
    self.maxProcesses.store(newValue, ordering: .relaxed)
  }

  public static func canStartNewProcess() -> Bool {
    let max = self.maxProcesses.load(ordering: .relaxed)
    let currentProcesses = self.processes.load(ordering: .relaxed)
    return currentProcesses < max
  }

  /// Try to acquire a new process, returning false if the max amount of processes is reached
  public static func tryNewProcess() async -> Bool {
    let max = self.maxProcesses.load(ordering: .relaxed)
    var done = false
    var currentProcesses = 0
    while true {
      currentProcesses = self.processes.load(ordering: .relaxed)
      if currentProcesses < max {
        (done, currentProcesses) = self.processes.weakCompareExchange(expected: currentProcesses, desired: currentProcesses + 1, ordering: .acquiringAndReleasing)
        if (done) { return true }
      } else {
        return false
      }
    }
  }

  /// Wait until a new process can be started
  public static func newProcess() async {
    let max = self.maxProcesses.load(ordering: .relaxed)
    var done = false
    var currentProcesses = 0
    while true {
      currentProcesses = self.processes.load(ordering: .relaxed)
      if currentProcesses < max {
        (done, currentProcesses) = self.processes.weakCompareExchange(expected: currentProcesses, desired: currentProcesses + 1, ordering: .acquiringAndReleasing)
        if (done) { break }
      }
      await Task.yield()
    }
  }

  /// Decrease the process count
  public static func releaseProcess() {
    self.processes.wrappingDecrement(ordering: .acquiringAndReleasing)
  }
}
