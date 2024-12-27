@preconcurrency import Semver

public enum Version: Sendable {
  case semver(Semver)
  case other(String)

  public init(_ versionString: String) {
    if let semver = Semver(versionString) {
      self = .semver(semver)
    } else {
      self = .other(versionString)
    }
  }

  public init(semver versionString: String) throws(CreationError) {
    if let semver = Semver(versionString) {
      self = .semver(semver)
    } else {
      throw .invalidSemversion(versionString)
    }
  }

  public enum CreationError: Error {
    case invalidSemversion(String)
  }
}

extension Version: Equatable, Comparable {
  public static func ==(lhs: Self, rhs: Self) -> Bool {
    switch (lhs) {
      case .semver(let lver):
        guard case .semver(let rver) = rhs else {
          return false
        }
        return lver == rver
      case .other(let ls):
        guard case .other(let rs) = rhs else {
          return false
        }
        return ls == rs
    }
  }

  public static func <(lhs: Self, rhs: Self) -> Bool {
    switch (lhs) {
      case .semver(let lver):
        guard case .semver(let rver) = rhs else {
          return false
        }
        return lver < rver
      case .other(_): return false
    }
  }

  public static func >(lhs: Self, rhs: Self) -> Bool {
    switch (lhs) {
      case .semver(let lver):
        guard case .semver(let rver) = rhs else {
          return false
        }
        return lver > rver
      case .other(_): return false
    }
  }
}
