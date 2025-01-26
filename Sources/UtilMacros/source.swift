import SwiftSyntax

func getSourceForProtocol(_ `protocol`: TokenSyntax) throws -> String {
  switch (`protocol`.text) {
    case "TargetBase":
      targetBaseCode
    case "Project":
      projectCode
    case "Library":
      libraryCode
    case "Target":
      targetCode
    case "CommandCapableProject":
      commandCapableProjectCode
    case "MutableProject":
      mutableProjectCode
    default:
      throw WrapperMacroError.undefined(`protocol`.text)
  }
}
