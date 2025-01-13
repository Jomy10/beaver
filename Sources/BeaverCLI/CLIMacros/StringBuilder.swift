@resultBuilder
public struct StringBuilder {
  public static func buildBlock(_ parts: String...) -> String {
    return parts.joined(separator: "\n")
  }

  public static func buildBlock(_ parts: [String]...) -> String {
    return parts.map { $0.joined(separator: "\n") }.joined(separator: "\n")
  }

  public static func buildEither(first component: String) -> String {
    return component
  }

  public static func buildEither(first component: [String]) -> String {
    return component.joined(separator: "\n")
  }

  public static func buildEither(second component: String) -> String {
    return component
  }

  public static func buildEither(second component: [String]) -> String {
    return component.joined(separator: "\n")
  }

  public static func buildArray(_ components: [String]) -> String {
    return components.joined(separator: "\n")
  }

  public static func buildExpression(_ expression: String) -> String {
    return expression
  }

  public static func buildOptional(_ component: String?) -> String {
    return component ?? ""
  }

  public static func buildLimitedAvailability(_ component: String) -> String {
    return component
  }
}

extension String {
  public init(@StringBuilder _ builder: () -> String) {
    self = builder()
  }
}
