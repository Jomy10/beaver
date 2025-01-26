import Foundation
import SwiftSyntax
import SwiftParser
import SwiftSyntaxMacros
import SwiftSyntaxBuilder

fileprivate func conform(to protocolToken: TokenSyntax, binding: PatternBindingSyntax) throws -> MemberBlockSyntax {
  let callInner = { (mutable: Bool, returns: TypeSyntax?, throws: Bool, call: (TokenSyntax) throws -> ExprSyntax) throws -> ExprSyntax in
    ExprSyntax(try call("\(binding.pattern).pointee"))
  }
  return try conform(to: protocolToken, callInner: callInner)
}

public struct PointerWrapper: ExtensionMacro {
  public static func expansion(
    of node: AttributeSyntax,
    attachedTo declaration: some DeclGroupSyntax,
    providingExtensionsOf type: some TypeSyntaxProtocol,
    conformingTo protocols: [TypeSyntax],
    in context: some MacroExpansionContext
  ) throws -> [ExtensionDeclSyntax] {
    guard let `struct` = declaration.as(StructDeclSyntax.self) else {
      throw WrapperMacroError.notStruct
    }

    for member in `struct`.memberBlock.members {
      guard let varDecl = member.decl.as(VariableDeclSyntax.self) else {
        continue
      }

      guard let pointerBinding = varDecl.bindings.first(where: { binding in
        let bindingType = binding.typeAnnotation?.type.as(IdentifierTypeSyntax.self)?.name.text
        return bindingType == "UnsafeMutablePointer"
      }) else {
        continue
      }

      return try protocols.map { (protocol: TypeSyntax) -> ExtensionDeclSyntax in
        let protocolIdentifierSyntax: IdentifierTypeSyntax = `protocol`.as(IdentifierTypeSyntax.self)!
        let protocolToken: TokenSyntax = protocolIdentifierSyntax.name

        let memberBlock = try conform(to: protocolToken, binding: pointerBinding)

        return ExtensionDeclSyntax(
          extendedType: type,
          inheritanceClause: InheritanceClauseSyntax(inheritedTypes: InheritedTypeListSyntax([InheritedTypeSyntax(type: `protocol`)])),
          memberBlock: memberBlock
        )
      }
    }
    throw WrapperMacroError.notPointerWrapper
  }
}
