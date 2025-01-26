enum WrapperMacroError: Error {
  case unknownProtocol(String)
  case notEnum
  case notStruct
  case notPointerWrapper
  /// there can only be one parameter in a case
  case caseParameterCount
  case undefined(String)
  case noProtocolDecl
  case wrongArgumentList(String? = nil)
  case bug
}
