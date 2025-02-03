public enum OptimizationMode: String, Sendable, Decodable, Hashable, Equatable {
  case debug
  case release
  // TODO: case custom(String)
}

extension OptimizationMode: CustomStringConvertible {
  public var description: String {
    switch (self) {
      case .debug: "debug"
      case .release: "release"
    }
  }
}

extension OptimizationMode {
  var cmakeDescription: String {
    switch (self) {
      case .debug: "Debug"
      case .release: "Release"
    }
  }

  var cflags: [String] {
    switch (self) {
      case .debug: ["-g", "-O0"]
      case .release: ["-O3"]
    }
  }
}
