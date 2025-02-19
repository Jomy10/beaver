import SwiftSyntax
import SwiftSyntaxMacros
import SwiftSyntaxBuilder

struct Column {
  let name: String
  let type: TypeSyntax
  let primaryKey: ExprSyntax?
  let unique: Bool
}

enum CacheEntryMacroError: Error {
  case notSupported(SyntaxProtocol.Type)
}

public struct CacheEntryMacro: ExtensionMacro, MemberMacro {
  public static func expansion(
    of node: SwiftSyntax.AttributeSyntax,
    attachedTo declaration: some SwiftSyntax.DeclGroupSyntax,
    providingExtensionsOf type: some SwiftSyntax.TypeSyntaxProtocol,
    conformingTo protocols: [SwiftSyntax.TypeSyntax],
    in context: some SwiftSyntaxMacros.MacroExpansionContext
  ) throws -> [SwiftSyntax.ExtensionDeclSyntax] {
    let typeName: String = if let decl = declaration.as(ActorDeclSyntax.self) {
      decl.name.text
    } else if let decl = declaration.as(StructDeclSyntax.self) {
      decl.name.text
    } else if let decl = declaration.as(ClassDeclSyntax.self) {
      decl.name.text
    } else if declaration.as(EnumDeclSyntax.self) != nil {
      throw CacheEntryMacroError.notSupported(EnumDeclSyntax.self)
    } else if declaration.as(ExtensionDeclSyntax.self) != nil {
      throw CacheEntryMacroError.notSupported(ExtensionDeclSyntax.self)
    } else if declaration.as(ProtocolDeclSyntax.self) != nil {
      throw CacheEntryMacroError.notSupported(ProtocolDeclSyntax.self)
    } else {
      fatalError("unreachable")
    }
    var tableName: ExprSyntax = ExprSyntax("\"\(raw: typeName)\"")
    if let arguments = node.arguments {
      switch (arguments) {
        case .argumentList(let labeledExprList):
          for labeledExpr in labeledExprList {
            switch (labeledExpr.label?.text) {
              case "name":
                tableName = labeledExpr.expression
              default:
                fatalError("unexpected label \(labeledExpr.label?.text ?? "nil")")
            }
          }
        default:
          break
      }
    }

    var columns: [Column] = []
    for member in declaration.memberBlock.members {
      guard let varDecl = member.decl.as(VariableDeclSyntax.self) else { continue }
      for binding in varDecl.bindings {
        guard let identifier = binding.pattern.as(IdentifierPatternSyntax.self) else { continue }
        let columnName = identifier.identifier.text
        let type: TypeSyntax = binding.typeAnnotation!.type
        if binding.accessorBlock != nil { continue }
        let primaryKey: ExprSyntax?
        if let attr = varDecl.attributes.first(where: { attr in
          guard let attr = attr.as(AttributeSyntax.self) else {
            return false
          }
          return attr.attributeName.as(IdentifierTypeSyntax.self)?.name.text == "PrimaryKey"
        }) {
          let param = attr.as(AttributeSyntax.self)!.arguments!.as(LabeledExprListSyntax.self)!.first!.expression
          primaryKey = param
        } else {
          primaryKey = nil
        }
        columns.append(Column(name: columnName, type: type, primaryKey: primaryKey, unique: false))
      }
    }

    // tableName //
    let tableNameDecl = try VariableDeclSyntax("static let tableName: String = \(tableName)")

    // create table //
    let columnDefinitions = columns.map { column in
      var args: [LabeledExprSyntax] = []
      args.append(LabeledExprSyntax(expression: ExprSyntax("SQLite.Expression<\(column.type)>(\"\(raw: column.name)\")")))
      if let param = column.primaryKey {
        args[args.count - 1].trailingComma = TokenSyntax(",")
        args.append(LabeledExprSyntax(label: TokenSyntax("primaryKey"), colon: TokenSyntax(":"), expression: ExprSyntax(param)))
        //additional += ", primaryKey: \(param)"
      }
      if column.unique {
        args[args.count - 1].trailingComma = TokenSyntax(",")
        args.append(LabeledExprSyntax(label: TokenSyntax("unique"), colon: TokenSyntax(":"), expression: ExprSyntax("true")))
        //additional += ", unqiue: true"
      }
      //return StmtSyntax("t.column(SQLite.Expression<\(column.type)>(\"\(raw: column.name)\")\(raw: additional))")
      return StmtSyntax("t.column(\(LabeledExprListSyntax(args)))")
    }
    // TODO: foreign keys
    let createIfNotExistsDecl = try FunctionDeclSyntax("""
    public static func createIfNotExists(_ db: Connection) throws {
      \(createTableCall(columnDefinitions, temporary: false))
    }
    """)

    let columnSwiftDefs = try columns.map { column in
      return try VariableDeclSyntax("""
      static let \(raw: column.name): TableColumn<\(column.type)> = TableColumn(\"\(raw: column.name)\", \(type).table)
      """)
    }
    let columnsDecl = StructDeclSyntax(
      name: TokenSyntax("Columns"),
      memberBlock: MemberBlockSyntax(members: MemberBlockItemListSyntax(columnSwiftDefs.map { MemberBlockItemSyntax(decl: DeclSyntax($0)) }))
    )

    let createTemporaryDecl = DeclSyntax(
      """
      public static func createTemporary(_ db: Connection) throws -> Table {
        let table = Table(Self.tableName + String(describing: UUID()))
        \(createTableCall(columnDefinitions, temporary:true))
        return table
      }
      """
    )

    // Setter //
    let setterDecl = try VariableDeclSyntax("""
    var setter: [SQLite.Setter] {
      \(insertArray(columns, prefix: "self"))
    }
    """)

    // insert //
    let insertManyDecl = try FunctionDeclSyntax(
      """
      /// returns the last id inserted
      @discardableResult
      public static func insertMany(_ entries: [Self], _ db: Connection) throws -> Int64 {
        try db.run(Self.table
          .insertMany(entries.map { (entry) in
            entry.setter
          }))
      }
      """
    )

    let insertDecl = try FunctionDeclSyntax(
      """
      @discardableResult
      public func insert(_ db: Connection) throws -> Int64 {
        try db.run(Self.table.insert(
          self.setter
        ))
      }
      """
    )

    // Table //
    let tableDecl = try VariableDeclSyntax("public static let table: SQLite.Table = SQLite.Table(Self.tableName)")

    // Get One //
    let getOneDecl = try FunctionDeclSyntax("""
    public static func getOne(_ db: Connection) throws -> SQLite.Row? {
      try db.pluck(Self.table.limit(1))
    }
    """)

    // Init //
    let initDecl = DeclSyntax("""
    public init(_ row: SQLite.Row) {
      \(CodeBlockItemListSyntax(columns.map { column in
        CodeBlockItemSyntax(item: CodeBlockItemSyntax.Item(StmtSyntax("self.\(raw: column.name) = row[Self.Columns.\(raw: column.name).qualified]")))
      }))
    }
    """)

    let members: [DeclSyntax] = [
      DeclSyntax(tableNameDecl),
      DeclSyntax(createIfNotExistsDecl),
      DeclSyntax(createTemporaryDecl),
      DeclSyntax(initDecl),
      DeclSyntax(columnsDecl),
      DeclSyntax(setterDecl),
      DeclSyntax(insertDecl),
      DeclSyntax(insertManyDecl),
      DeclSyntax(tableDecl),
      DeclSyntax(getOneDecl)
    ]
    return [
      ExtensionDeclSyntax(
        extendedType: type,
        inheritanceClause: InheritanceClauseSyntax(colon: ":", inheritedTypes: InheritedTypeListSyntax(protocols.map { InheritedTypeSyntax(type: $0) })),
        memberBlock: MemberBlockSyntax(members: MemberBlockItemListSyntax(
          members.map { MemberBlockItemSyntax(decl: $0) }
        ))
      )
    ]
  }
}

func insertArray(_ columns: [Column], prefix: String) -> ArrayExprSyntax {
  ArrayExprSyntax(elements: ArrayElementListSyntax(columns.map { col in
    ArrayElementSyntax(
      expression: ExprSyntax("Self.Columns.\(raw: col.name).unqualified <- \(raw: prefix).\(raw: col.name)"),
      trailingComma: ","
    )
  }))
}

func createTableCall(_ columns: [StmtSyntax], temporary: Bool) -> FunctionCallExprSyntax {
  return FunctionCallExprSyntax(
    calledExpression: ExprSyntax("try db.run"),
    leftParen: "(",
    arguments: LabeledExprListSyntax([LabeledExprSyntax(label: nil, expression: FunctionCallExprSyntax(
      calledExpression: temporary ? ExprSyntax("table.create") : ExprSyntax("Self.table.create"),
      leftParen: "(",
      arguments:
        temporary
          ? LabeledExprListSyntax([LabeledExprSyntax(
            label: TokenSyntax("temporary"),
            colon: ":",
            expression: ExprSyntax("true")
          )])
          : LabeledExprListSyntax([LabeledExprSyntax(
            label: TokenSyntax("ifNotExists"),
            colon: ":",
            expression: ExprSyntax("true")
          )]),
      rightParen: ")",
      trailingClosure: ClosureExprSyntax(
        leftBrace: "{",
        signature: ClosureSignatureSyntax(
          parameterClause: ClosureSignatureSyntax.ParameterClause(ClosureShorthandParameterListSyntax([ClosureShorthandParameterSyntax(name: "t ")])),
          inKeyword: TokenSyntax(" in ")
        ),
        statements: CodeBlockItemListSyntax(
          columns.map { stmt in
            CodeBlockItemSyntax(item: CodeBlockItemSyntax.Item(stmt))
          }
        ),
        rightBrace: "}"
      )
    ))]),
    rightParen: ")"
  )
}
