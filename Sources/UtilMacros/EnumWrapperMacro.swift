import Foundation
import SwiftSyntax
import SwiftParser
import SwiftSyntaxMacros
import SwiftSyntaxBuilder

fileprivate func conform(
  to protocolToken: TokenSyntax,
  enumCases: [TokenSyntax],
  skipping: [String]
) throws -> MemberBlockSyntax {
  let callInner = { (mutable: Bool, returns: TypeSyntax?, `throws`: Bool, call: (TokenSyntax) throws -> ExprSyntax) throws -> ExprSyntax in
    let cases: [SwitchCaseSyntax] = try enumCases.map { enumCase in
      if skipping.contains(enumCase.description) {
        return SwitchCaseSyntax("""
        case .\(enumCase)(_):
          fatalError("cannot call on \(raw: enumCase.description)")
        """)
      } else {
        var stmnts = [StmtSyntax]()
        if let returnType = returns {
          stmnts.append(StmtSyntax("let ret: \(returnType)"))
        }

        let callStmt = if returns != nil {
          StmtSyntax("ret = \(try call(TokenSyntax("val")))")
        } else {
          StmtSyntax("\(try call(TokenSyntax("val")))")
        }

        //let stmnt: StmtSyntax
        if `throws` {
          var bodyStatements = [CodeBlockItemSyntax]()
          if mutable {
            bodyStatements.append(CodeBlockItemSyntax(item: .stmt(StmtSyntax("self = .\(enumCase)(consume val)"))))
          }
          bodyStatements.append(CodeBlockItemSyntax(item: .stmt(StmtSyntax("throw error"))))
          stmnts.append(StmtSyntax(DoStmtSyntax(
            body: CodeBlockSyntax(
              statements: CodeBlockItemListSyntax([CodeBlockItemSyntax(item: .stmt(callStmt))])
            ),
            catchClauses: CatchClauseListSyntax([CatchClauseSyntax(
              catchItems: CatchItemListSyntax([CatchItemSyntax(
                pattern: PatternSyntax(" let error")
              )]),
              body: CodeBlockSyntax(statements: CodeBlockItemListSyntax(bodyStatements))
            )])
          )))
        } else {
          stmnts.append(callStmt)
        }
        if mutable {
          stmnts.append(StmtSyntax("self = .\(enumCase)(consume val)"))
        }
        if returns != nil {
          stmnts.append(StmtSyntax("return ret"))
        }
        return SwitchCaseSyntax(
          label: .`case`(SwitchCaseLabelSyntax(caseItems: SwitchCaseItemListSyntax([
            //SwitchCaseItemSyntax(pattern: PatternSyntax(IdentifierPatternSyntax(identifier: enumCase)))
            SwitchCaseItemSyntax(
              pattern: PatternSyntax(".\(enumCase)(\(raw: mutable ? "var" : "let") val)")
            )
          ]))),
          statements: CodeBlockItemListSyntax(stmnts.map { CodeBlockItemSyntax(item: .stmt(StmtSyntax("\($0);"))) })
        )
      }
    }
    let caseList = SwitchCaseListSyntax(cases.map { .switchCase($0) })
    let expr = SwitchExprSyntax(
      subject: ExprSyntax("self"),
      cases: caseList
    )
    return ExprSyntax(expr)
  }

  return try conform(to: protocolToken, callInner: callInner)
}

/// implement Protocol for enum, calling methods on members
public struct EnumWrapper: ExtensionMacro {
  public static func expansion(
    of node: AttributeSyntax,
    attachedTo declaration: some DeclGroupSyntax,
    providingExtensionsOf type: some TypeSyntaxProtocol,
    conformingTo protocols: [TypeSyntax],
    in context: some MacroExpansionContext
  ) throws -> [ExtensionDeclSyntax] {
    var stringArgs = [String:[String]]()
    if let arguments = node.arguments {
      guard let argList = arguments.as(LabeledExprListSyntax.self) else {
        throw WrapperMacroError.wrongArgumentList("Arguments not a LabeledExprListSyntax; \(arguments)")
      }
      for label in argList {
        if label.expression.is(NilLiteralExprSyntax.self) {
          continue
        }
        guard let expr = label.expression.as(ArrayExprSyntax.self) else {
          throw WrapperMacroError.wrongArgumentList()
        }
        var strings = [String]()
        for element in expr.elements {
          guard let str = element.expression.as(StringLiteralExprSyntax.self) else {
            print("not string")
            throw WrapperMacroError.wrongArgumentList()
          }
          strings.append(str.segments.description)
        }
        stringArgs[label.label!.description] = strings
      }
    }

    guard let `enum` = declaration.as(EnumDeclSyntax.self) else {
      throw WrapperMacroError.notEnum
    }

    var enumCaseNames: [TokenSyntax] = []
    for enumCase in `enum`.memberBlock.members {
      guard let caseDecl = enumCase.decl.as(EnumCaseDeclSyntax.self) else {
        continue
      }

      for element in caseDecl.elements {
        enumCaseNames.append(element.name)
        if element.parameterClause?.parameters.count != 1 {
          throw WrapperMacroError.caseParameterCount
        }
      }
    }


    return try protocols.map { (protocol: TypeSyntax) -> ExtensionDeclSyntax in
      let protocolIdentifierSyntax: IdentifierTypeSyntax = `protocol`.as(IdentifierTypeSyntax.self)!
      let protocolToken: TokenSyntax = protocolIdentifierSyntax.name

      let memberBlock = try conform(to: protocolToken, enumCases: enumCaseNames, skipping: stringArgs["skipping"] ?? [])

      return ExtensionDeclSyntax(
        extendedType: type,
        inheritanceClause: InheritanceClauseSyntax(inheritedTypes: InheritedTypeListSyntax([InheritedTypeSyntax(type: `protocol`)])),
        memberBlock: memberBlock
      )
    }
  }
}
