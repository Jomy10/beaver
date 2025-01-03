public enum Language: Sendable {
  case c
  case swift
  case other(String)
}

extension Language: Equatable, Hashable {
  public static func ==(lhs: Self, rhs: Self) -> Bool {
    switch (lhs) {
      case .c: return rhs == .c
      case .swift: return rhs == .swift
      case .other(let s):
        guard case .other(let sOther) = rhs else {
          return false
        }
        return s == sOther
    }
  }
}
