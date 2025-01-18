extension Sequence {
  public func compactFlatMap<Result>(_ cb: (Element) throws -> [Result]?) rethrows -> [Result] {
    var result: [Result] = []
    for elem in self {
      switch (try cb(elem)) {
        case .none: continue
        case .some(let val):
          result.append(contentsOf: val)
      }
    }
    return result
  }
}
