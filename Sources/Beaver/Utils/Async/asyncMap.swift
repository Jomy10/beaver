extension Sequence {
  func asyncMap<ResultType>(_ cb: (borrowing Element) async throws -> ResultType) async rethrows -> [ResultType] {
    var res: [ResultType] = []
    for el in self {
      res.append(try await cb(el))
    }
    return res
  }
}
