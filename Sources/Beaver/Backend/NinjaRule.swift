import Utils

struct NinjaRule: Sendable {
  let name: String
  let values: [String: String]

  init(name: String, values: [String: String]) {
    self.name = name
    self.values = values
  }
}

extension NinjaRule: Hashable {
  func hash(into hasher: inout Hasher) {
    hasher.combine(self.name)
  }
}

extension Language {
  func ninjaRules(into rules: inout Set<NinjaRule>) throws {
    switch (self) {
      case .objc:
        #if !os(macOS)
        _ = Tools.requireGNUStep
        #endif
        fallthrough
      case .c:
        rules.insert(.init(name: self.compileRule, values: [
          "depfile": "$out.d",
          "deps": "gcc",
          "command": "\(try Tools.requireCC.path) \(self.cflags()?.map { "\"\($0)\"" }.joined(separator: " ") ?? "") $cflags -MD -MF $out.d -c $in -o $out",
          "description": "cc $in > $out"
        ]))
        rules.insert(.init(name: self.linkRule, values: [
          "command": "\(Tools.cc!.path) $linkerFlags $in -o $out",
          "description": "link $in > $out"
        ]))
        rules.insert(.init(name: "ar", values: [
          "command": "\(try Tools.requireAR.path) -rc $out $in",
          "description": "ar $in > $out"
        ]))
      case .objcxx:
        #if !os(macOS)
        _ = Tools.requireGNUStep
        #endif
        fallthrough
      case .cxx:
        rules.insert(.init(name: self.compileRule, values: [
          "depfile": "$out.d",
          "deps": "gcc",
          "command": "\(try Tools.requireCXX.path) \(self.cflags()?.map { "\"\($0)\"" }.joined(separator: " ") ?? "") $cflags -MD -MF $out.d -c $in -o $out",
          "description": "cxx $in > $out"
        ]))
        rules.insert(.init(name: self.linkRule, values: [
          "command": "\(Tools.cxx!.path) $linkerFlags $in -o $out",
          "description": "link $in > $out"
        ]))
        rules.insert(.init(name: "ar", values: [
          "command": "\(try Tools.requireAR.path) -rc $out $in",
          "description": "ar $in > $out"
        ]))
    }
  }

  var compileRule: String {
    switch (self) {
      case .c: "cc"
      case .cxx: "cxx"
      case .objc: "objcc"
      case .objcxx: "objcxx"
    }
  }

  var linkRule: String {
    switch (self) {
      case .objc: fallthrough
      case .c: return "link"
      case .objcxx: fallthrough
      case .cxx: return "linkxx"
    }
  }
}

//enum NinjaRule: String {
//  case cc
//  case cxx
//  case objcc
//  case objcxx
//  case link
//  case ar
//}

//struct ToolValidationError {
//  let tool: String
//  let message: String?

//  init(tool: String, _ message: String? = nil) {
//    self.tool = tool
//    self.message = message
//  }
//}

//extension NinjaRule {
//  var description: String {
//    get throws {
//      var str = "rule \(self)\n"
//      switch (self) {
//        case .objcc: fallthrough
//        case .objcxx: fallthrough
//        case .cxx: fallthrough
//        case .cc:
//          str.appendLine("""
//              depfile = $out.d
//              deps = gcc
//              command = \(try self.requireTool()) $cflags -MD -MF $out.d -c $in -o $out
//          """)
//        case .ar:
//          str.appendLine("""
//              command = \(try self.requireTool()) -rc $out $in
//          """)
//        case .linkc:
//          str.appendLine("""
//              command = \(try Self.cc.requireTool())
//          """)
//      }
//    }
//  }

//  func requireTool() throws(ToolValidationError) -> String {
//    switch (self) {
//      case .cc:
//        guard let cc = Tools.cc else {
//          throw ToolValidationError(tool: "cc", "Couldn't be found")
//        }
//        return cc.path
//      case .cxx:
//        guard let cxx = Tools.cc else {
//          throw ToolValidationError(tool: "cxx", "Couldn't be found")
//        }
//        return cxx.path
//      case .objcxx: fallthrough
//      case .objc:
//        guard let objc = Tools.objcCompile else {
//          throw ToolValidationError(tool: "objc", "Couldn't be found")
//        }
//        return objc.path
//      case .ar:
//        guard let ar = Tools.ar else {
//          throw ToolValidationError(tool: "ar", "Couldn't be found")
//        }
//        return ar.path
//    }
//  }
//}
