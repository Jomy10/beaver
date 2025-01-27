import Utils

public enum Language: Sendable, Equatable, Hashable {
  case c
  case cxx
  case objc
  case objcxx
  case swift
}

extension Language {
  public init?(fromString string: String) {
    switch (string.lowercased()) {
      case "c":
        self = .c
      case "c++": fallthrough
      case "cxx": fallthrough
      case "cpp":
        self = .cxx
      case "objc": fallthrough
      case "obj-c":
        self = .objc
      case "objc++": fallthrough
      case "obj-c++": fallthrough
      case "objcxx": fallthrough
      case "obj-cxx": fallthrough
      case "objcpp": fallthrough
      case "obj-cpp":
        self = .objcxx
      case "swift":
        self = .swift
      default: return nil
    }
  }

  init?(fromCMake cmakeLanguageString: String) {
    switch (cmakeLanguageString) {
      case "C": self = .c
      case "CXX": self = .cxx
      // case "FORTRAN": self = .fortran
      default: return nil
    }
  }

  func cflags() -> [String]? {
    switch (self) {
      case .objc: return Tools.objcCflags
      case .objcxx: return Tools.objcxxCflags
      default: return nil
    }
  }

  /// Linker flags to link from language `self` to `targetLanguage`
  func linkerFlags(targetLanguage: Language) -> [String]? {
    switch (self) {
      case .c: break
      case .objc:
        return Tools.objcLinkerFlags
      case .objcxx:
        if let cxxLinkerFlags = Self.cxxLinkerFlags(targetLanguage: targetLanguage) {
          return Tools.objcLinkerFlags + cxxLinkerFlags
        } else {
          return Tools.objcLinkerFlags
        }
      case .cxx:
        return Self.cxxLinkerFlags(targetLanguage: targetLanguage)
      case .swift:
        MessageHandler.warn("Unimplemented: Swift")
        break
    }
    return nil
  }

  static func cxxLinkerFlags(targetLanguage: Language) -> [String]? {
    if Array<Language>([.c, .objc]).contains(targetLanguage) {
      return ["-lstdc++"]
    } else {
      return nil
    }
  }
}

extension Language: CustomStringConvertible {
  public var description: String {
    switch (self) {
      case .c: "C"
      case .cxx: "C++"
      case .objc: "Obj-C"
      case .objcxx: "Obj-C++"
      case .swift: "Swift"
    }
  }
}

//extension Language: Equatable, Hashable {
//  public static func ==(lhs: Self, rhs: Self) -> Bool {
//    switch (lhs) {
//      case .c: return rhs == .c
//      case .swift: return rhs == .swift
//      case .cxx: return
//      case .other(let s):
//        guard case .other(let sOther) = rhs else {
//          return false
//        }
//        return s == sOther
//    }
//  }
//}
