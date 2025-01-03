extension Sequence {
  func asyncMap<ResultType>(_ cb: (borrowing Element) async throws -> ResultType) async rethrows -> [ResultType] {
    var res: [ResultType] = []
    for el in self {
      res.append(try await cb(el))
    }
    return res
  }

  func asyncFilter(_ cb: (borrowing Element) async throws -> Bool) async rethrows -> [Element] {
    var res: [Element] = []
    for el in self {
      if (try await cb(el)) {
        res.append(el)
      }
    }
    return res
  }
}
