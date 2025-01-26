import SwiftSyntax
import SwiftSyntaxMacros
import SwiftSyntaxBuilder

struct ArgumentDecl {
  var variableName: TokenSyntax
  var variableType: TypeSyntax
  var fullName: ExprSyntax
  var shortName: ExprSyntax? = nil
  var negatable: ExprSyntax? = nil
  var help: ExprSyntax? = nil
  var defaultInitializer: ExprSyntax? = nil

  var isFlag: Bool

  var syntax: ExprSyntax {
    get {
      let name = self.isFlag ? "FlagDecl" : "ArgumentDecl"
      return ExprSyntax(
        """
        \(raw: name)(
          fullName: \(self.fullName),
          shortName: \(self.shortName ?? ExprSyntax("nil")),
          \({
            if let negatableExpr = self.negatable {
              "negatable: \(negatableExpr),"
            } else {
              ""
            }
          }())
          help: \(self.help ?? ExprSyntax("nil"))
        )
        """
      )
    }
  }
}

public struct CLIMacro: ExtensionMacro, MemberMacro {
  public static func expansion(
    of node: AttributeSyntax,
    providingMembersOf declaration: some DeclGroupSyntax,
    in context: some MacroExpansionContext
  ) throws -> [DeclSyntax] {
    //== Leftover arguments ==//
    let leftoverArgsVarDecl = try VariableDeclSyntax(
      "var leftoverArguments: DiscontiguousSlice<[String].SubSequence>"
    )

    return [DeclSyntax(leftoverArgsVarDecl)]
  }

  public static func expansion(
    of node: SwiftSyntax.AttributeSyntax,
    attachedTo declaration: some SwiftSyntax.DeclGroupSyntax,
    providingExtensionsOf type: some SwiftSyntax.TypeSyntaxProtocol,
    conformingTo protocols: [SwiftSyntax.TypeSyntax],
    in context: some SwiftSyntaxMacros.MacroExpansionContext
  ) throws -> [SwiftSyntax.ExtensionDeclSyntax] {
    //== static let _arguments ==//
    var argumentDecls: [ArgumentDecl] = []

    // Collect argument declarations
    for decl in declaration.memberBlock.members {
      guard let member = MemberBlockItemSyntax(decl) else { continue }
      guard let variable = member.decl.as(VariableDeclSyntax.self) else { continue }
      if variable.attributes.count == 0 { continue }

      let varName = variable.bindings.first!.pattern.as(IdentifierPatternSyntax.self)!.identifier
      let varType = variable.bindings.first!.typeAnnotation!.type

      for attribute in variable.attributes {
        guard let attributeSyntax = attribute.as(AttributeSyntax.self) else { continue }
        let attrName = attributeSyntax.attributeName.as(IdentifierTypeSyntax.self)!.name.text
        if attrName != "Argument" && attrName != "Flag" { continue }

        let arguments = attributeSyntax.arguments!.as(LabeledExprListSyntax.self)!

        let argDecl = ArgumentDecl(
          variableName: varName,
          variableType: varType,
          fullName: arguments.first { expr in
            expr.label?.text == "name"
          }!.expression,
          shortName: arguments.first { expr in
            expr.label?.text == "shortName"
          }?.expression,
          negatable: arguments.first { expr in
            expr.label?.text == "negatable"
          }?.expression,
          help: arguments.first { expr in
            expr.label?.text == "help"
          }?.expression,
          defaultInitializer: arguments.first { expr in
            expr.label?.text == "default"
          }?.expression,
          isFlag: attrName == "Flag"
        )
        argumentDecls.append(argDecl)
      }
    }

    let argumentsElems: [ArrayElementSyntax] = argumentDecls
      .map { $0.syntax }
      .enumerated()
      .map { (i, syntax) in
        ArrayElementSyntax(
          expression: syntax,
          trailingComma: i == argumentDecls.count - 1 ? nil : ","
        )
      }
    let argsVarDecl: VariableDeclSyntax = try VariableDeclSyntax(
      "static let _arguments: [any ArgumentProtocol] = \(ArrayExprSyntax(elements: ArrayElementListSyntax(argumentsElems)))"
    )

    //== init ==//
    let funcDeclString = String {
      """
      public init(arguments: borrowing [String].SubSequence) throws {
        let (leftover, parsed) = try Self.parseArguments(arguments)
        self.leftoverArguments = leftover
      """

      for argDecl in argumentDecls {
        let arg = if argDecl.isFlag {
          "(\(argDecl.variableName) as! FlagDecl.Parsed).value"
        } else {
          "try \(argDecl.variableType)(argument: (\(argDecl.variableName) as! ArgumentDecl.Parsed).value)"
        }

        """
        if let \(argDecl.variableName) = parsed[\(argDecl.fullName)] {
          self.\(argDecl.variableName) = \(arg)
        }
        """
        if let defaultInit = argDecl.defaultInitializer {
          """
          else {
            self.\(argDecl.variableName) = \(defaultInit)()
          }
          """
        }
      }

      "try self.validate()"

      "}"
    }
    let initFn = DeclSyntax("\(raw: funcDeclString)")

    return [
      ExtensionDeclSyntax(
        extendedType: type,
        inheritanceClause: InheritanceClauseSyntax(colon: ":", inheritedTypes: InheritedTypeListSyntax(protocols.map { InheritedTypeSyntax(type: $0) }))
      ) {
        argsVarDecl
        initFn
      }
    ]
    //return [varDecl.as(DeclSyntax.self)!]
  }
}
