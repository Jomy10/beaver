public protocol MutableProject: ~Copyable, Project, Sendable {
  @discardableResult
  mutating func addTarget(_ target: consuming AnyTarget) async -> TargetRef
}
