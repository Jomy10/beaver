import SwiftSyntax
import SwiftParser
import SwiftSyntaxMacros
import SwiftSyntaxBuilder

func conform(
  to protocolToken: TokenSyntax,
  callInner: (Bool, TypeSyntax?, Bool, (TokenSyntax) throws -> ExprSyntax) throws -> ExprSyntax
) throws -> MemberBlockSyntax {
  let sourceFile: SourceFileSyntax = Parser.parse(source: try getSourceForProtocol(protocolToken))

  for statement in sourceFile.statements {
    guard case .decl(let decl) = statement.item else { continue }
    guard let protocolDecl = decl.as(ProtocolDeclSyntax.self) else { continue }
    if protocolDecl.name.text != protocolToken.text { continue }

    var declarations: [DeclSyntax] = []
    for member in protocolDecl.memberBlock.members {
      //switch (member.decl.`as`(DeclSyntaxEnum.self)) {
      //  case .functionDecl(var funcDecl):
      if var funcDecl = member.decl.as(FunctionDeclSyntax.self) {
        let paramCount = funcDecl.signature.parameterClause.parameters.count
        funcDecl.modifiers = [DeclModifierSyntax(name: TokenSyntax("public"))] + funcDecl.modifiers
        var callModifiers = ""
        if funcDecl.signature.effectSpecifiers?.throwsClause != nil {
          callModifiers += "try "
        }
        if funcDecl.signature.effectSpecifiers?.asyncSpecifier != nil {
          callModifiers += "await "
        }
        funcDecl.body = CodeBlockSyntax(statements: [
          CodeBlockItemSyntax(item: .expr(
            ExprSyntax(try callInner(
              funcDecl.modifiers.contains(where: { $0.name.text == "mutating" }),
              funcDecl.signature.returnClause?.type,
              funcDecl.signature.effectSpecifiers?.throwsClause != nil,
              { variable in
                ExprSyntax(FunctionCallExprSyntax(
                  calledExpression: ExprSyntax("\(raw: callModifiers)\(variable).\(funcDecl.name)"),
                  leftParen: "(",
                  arguments: LabeledExprListSyntax(
                    funcDecl.signature.parameterClause.parameters.enumerated().map { (i, parameter) in
                      let parenName: TokenSyntax? = parameter.firstName == "_" ? nil : parameter.firstName
                      let callName: TokenSyntax = parameter.secondName ?? parameter.firstName
                      return LabeledExprSyntax(
                        label: parenName,
                        colon: parenName == nil ? nil : ":",
                        expression: ExprSyntax("\(callName)"),
                        trailingComma: i == paramCount - 1 ? nil : ","
                      )
                    }
                  ),
                  rightParen: ")"
                ))
              }
            ))
          ))
        ])
        declarations.append(DeclSyntax(funcDecl))
      } else if let varDecl = member.decl.as(VariableDeclSyntax.self) {
        var modifiers = varDecl.modifiers
        let publicModifier = DeclModifierSyntax(name: "public")
        if !modifiers.contains(publicModifier) {
          modifiers = [publicModifier] + modifiers
        }
        var bindings = varDecl.bindings
        bindings = try PatternBindingListSyntax(bindings.map { (_binding: PatternBindingSyntax) in
          var binding = _binding
          binding.initializer = nil
          let accessor = try binding.accessorBlock?.accessors.as(AccessorDeclListSyntax.self)!.map { (_accessor: AccessorDeclSyntax) in
            //guard case .accessor(var accessor) = accessor else { fatalError("bug") }
            var accessor = _accessor
            accessor.body = CodeBlockSyntax(statements: [
              CodeBlockItemSyntax(item: .expr(ExprSyntax(try callInner(
                accessor.accessorSpecifier.text == "set",
                accessor.accessorSpecifier.text == "get" ? binding.typeAnnotation!.type : nil,
                accessor.effectSpecifiers?.throwsClause != nil,
                { variable in
                  if accessor.accessorSpecifier.text == "get" {
                    ExprSyntax("\(variable).\(binding.pattern)")
                  } else if accessor.accessorSpecifier.text == "set" {
                    ExprSyntax("\(variable).\(binding.pattern) = newValue")
                  } else {
                    throw WrapperMacroError.bug
                  }
                }
              ))))
            ])
            return accessor
          }
          if let accessor = accessor {
            binding.accessorBlock?.accessors = .accessors(AccessorDeclListSyntax(accessor))
          }
          return binding
        })
        declarations.append(DeclSyntax(VariableDeclSyntax(
          modifiers: modifiers,
          bindingSpecifier: varDecl.bindingSpecifier,
          bindings: bindings
        )))
      }
    }
    return MemberBlockSyntax(members: MemberBlockItemListSyntax(declarations.map { MemberBlockItemSyntax(decl: $0) }))
  }

  throw WrapperMacroError.noProtocolDecl
}
