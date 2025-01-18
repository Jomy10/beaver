import Foundation

extension Process {
  public func waitUntilExitAsync() async {
    await withCheckedContinuation { c in
      self.terminationHandler = { _ in c.resume() }
    }
  }
}
