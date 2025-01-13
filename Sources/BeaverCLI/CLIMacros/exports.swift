import SwiftSyntaxMacros
import SwiftCompilerPlugin

@main
struct CLIMacros: CompilerPlugin {
  var providingMacros: [Macro.Type] = [
    CLIMacro.self
  ]
}
