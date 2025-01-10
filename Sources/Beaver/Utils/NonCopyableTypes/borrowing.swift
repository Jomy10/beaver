import Utils

func borrowN<NC: ~Copyable, Result>(_ nc: borrowing NC, n: Int, _ cb: (Int, borrowing NC) throws -> Result) rethrows -> [Result] {
  try (0..<n).map { i in
    try cb(i, nc)
  }
}

/// Borrows the 2 types `n` times
func borrow2N<NC1: ~Copyable, NC2: ~Copyable, Result>(
  _ nc1: borrowing NC1,
  _ nc2: borrowing NC2,
  n: Int,
  _ cb: (borrowing NC1, borrowing NC2) throws -> Result
) rethrows -> [Result] {
  try (0..<n).map { i in
    try cb(nc1, nc2)
  }
}

func borrow2N<NC1: ~Copyable, NC2: ~Copyable>(
  _ nc1: borrowing NC1,
  _ nc2: borrowing NC2,
  n: Int,
  _ cb: @escaping @Sendable (Int, borrowing NC1, borrowing NC2) async throws -> ()
) async throws {
  let nc1Ptr = UnsafeSendable(withUnsafePointer(to: nc1) { $0 })
  let nc2Ptr = UnsafeSendable(withUnsafePointer(to: nc2) { $0 })

  let tasks = await (0..<n).asyncMap { i in
    await GlobalThreadCounter.newProcess()
    return Task.detached(priority: .high) {
      try await cb(i, nc1Ptr.value.pointee, nc2Ptr.value.pointee)
    }
  }

  for (i, task) in tasks.enumerated() {
    switch (await task.result) {
      case .failure(let error):
        if i != tasks.count - 1 {
          for task in tasks[(i+1)...] {
            task.cancel()
            _ = await task.result
          }
        }
        throw error
      case .success(()):
        break
    }
  }
}
