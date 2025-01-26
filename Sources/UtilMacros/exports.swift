import SwiftSyntaxMacros
import SwiftCompilerPlugin

@main
struct UtilMacros: CompilerPlugin {
  var providingMacros: [Macro.Type] = [
    EnumWrapper.self,
    PointerWrapper.self
  ]
}
