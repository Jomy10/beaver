import Foundation

@ProjectWrapper
@CommandCapableProjectWrapper(skipping: nil)
@MutableProjectWrapper(skipping: nil)
public enum AnyProject: ~Copyable, Sendable {
  case beaver(BeaverProject)
}

extension AnyProject {
  func asCommandCapable<Result>(_ cb: (borrowing AnyCommandCapableProjectRef) async throws -> Result) async throws -> Result {
    switch (self) {
      case .beaver(_):
        let ptr = withUnsafePointer(to: self) { $0 }
        return try await cb(AnyCommandCapableProjectRef(UnsafeMutablePointer(mutating: ptr)))
    }
  }

  mutating func asCommandCapable<Result>(_ cb: (inout AnyCommandCapableProjectRef) async throws -> Result) async throws -> Result {
    switch (self) {
      case .beaver(_):
        break
    }
    let ptr = withUnsafeMutablePointer(to: &self) { $0 }
    var ref = AnyCommandCapableProjectRef(ptr)
    return try await cb(&ref)
  }

  public mutating func asMutable<Result>(_ cb: (inout AnyMutableProjectRef) async throws -> Result) async throws -> Result {
    switch (self) {
      case .beaver(_):
        break
    }
    let ptr = withUnsafeMutablePointer(to: &self) { $0 }
    var ref = AnyMutableProjectRef(ptr)
    return try await cb(&ref)
  }
}

public enum ProjectAccessError: Error {
  case noDefaultProject
  case noProject(named: String)
  case notCommandCapable
  case notMutable
}

@ProjectPointerWrapper
@CommandCapableProjectPointerWrapper
public struct AnyCommandCapableProjectRef: ~Copyable, @unchecked Sendable {
  let inner: UnsafeMutablePointer<AnyProject>

  init(_ inner: UnsafeMutablePointer<AnyProject>) {
    self.inner = inner
  }
}

@ProjectPointerWrapper
@MutableProjectPointerWrapper
public struct AnyMutableProjectRef: ~Copyable, @unchecked Sendable {
  let inner: UnsafeMutablePointer<AnyProject>

  init(_ inner: UnsafeMutablePointer<AnyProject>) {
    self.inner = inner
  }
}
