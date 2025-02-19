import SwiftSyntax
import SwiftSyntaxMacros
import SwiftSyntaxBuilder

public struct PrimaryKeyMacro: PeerMacro {
  public static func expansion(
    of node: AttributeSyntax,
    providingPeersOf declaration: some DeclSyntaxProtocol,
    in context: some MacroExpansionContext
  ) throws -> [SwiftSyntax.DeclSyntax] {
    return []
  }
}
