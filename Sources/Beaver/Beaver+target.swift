extension Beaver {
  func isBuildable(target: TargetRef) async throws -> Bool {
    try await self.withTarget(target) { (target: borrowing any Target) in target.buildableTarget }
  }
}
