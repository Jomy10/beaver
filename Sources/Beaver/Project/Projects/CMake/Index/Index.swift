import Foundation

struct CMakeIndexV1: Codable {
  let cmake: CMakeInstanceInformation
  let objects: [CMakeReplyObject]
  //let reply: [String:CMakeReplyObject]

  var codemodel: CMakeReplyObject? {
    self.objects.first(where: { $0.kind == "codemodel" })
  }

  var cache: CMakeReplyObject? {
    self.objects.first(where: { $0.kind == "cache" })
  }

  var cmakeFiles: CMakeReplyObject? {
    self.objects.first(where: { $0.kind == "cmakeFiles" })
  }
}

struct CMakeInstanceInformation: Codable {
  let version: CMakeInstanceVersion
  /// CMake Tool --> Path
  let paths: [String: String]
  let generator: CMakeGenerator?
}

struct CMakeInstanceVersion: Codable {
  let major: UInt
  let minor: UInt
  let patch: UInt
  let suffix: String
  let string: String
  let isDirty: Bool
}

struct CMakeGenerator: Codable {
  let multiConfig: Bool
  let name: String
  let platform: String?
}

struct CMakeReplyObject: Codable {
  let jsonFile: String
  let kind: String
  let version: CMakeObjectVersion

  var url: URL {
    URL(filePath: self.jsonFile)
  }

  var path: String {
    self.jsonFile
  }
}
