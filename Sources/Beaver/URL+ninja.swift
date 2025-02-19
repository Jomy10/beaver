import Foundation

extension URL {
  public var ninjaPath: String {
    self.path(percentEncoded: false).replacing(" ", with: "$ ")
  }
}
