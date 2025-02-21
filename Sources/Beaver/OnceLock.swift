import Atomics

/// A process can acquire with `startAcquire`, other processes calling this function
/// will wait until the original process calls `acquireFinish`, at which point they
/// will receive a `AcquireStatus.alreadyAcquired` return value, prompting them to stop
struct OnceLock {
  private let acquired = ManagedAtomic(false)
  private let locked = ManagedAtomic(false)

  enum AcquireStatus {
    case alreadyAcquired
    case acquired
  }

  func startAcquire() async -> AcquireStatus {
    if self.acquired.load(ordering: .relaxed) {
      return .alreadyAcquired
    }

    while !self.acquired.load(ordering: .relaxed) {
      if !self.locked.load(ordering: .relaxed) {
        let (exchanged, _) = self.locked.weakCompareExchange(expected: false, desired: true, ordering: .acquiring)
        if exchanged {
          if self.acquired.load(ordering: .relaxed) {
            return .alreadyAcquired
          } else {
            return .acquired
          }
        }
      }
      await Task.yield()
    }

    return .alreadyAcquired
  }

  func acquireFinish() {
    self.locked.store(false, ordering: .releasing)
    self.acquired.store(true, ordering: .relaxed)
  }

  func isAcquired() async -> Bool {
    if self.acquired.load(ordering: .relaxed) {
      return true
    }

    while self.locked.load(ordering: .relaxed) {
      await Task.yield()
    }

    return self.acquired.load(ordering: .relaxed)
  }
}
