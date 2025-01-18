import Beaver
import RubyGateway
import Utils

struct DependencyFuture {
  let data: Data

  static nonisolated(unsafe) var registered: [DependencyFuture.Data] = []

  enum Data {
    case target(target: String, project: String?, artifact: LibraryArtifactType? = nil)
    case pkgconfig(name: String, preferStatic: Bool = false)
    case system(name: String)

    func resolve(_ context: borrowing Beaver) async throws -> Dependency {
      switch (self) {
        case .target(target: let targetName, project: nil, artifact: let artifact):
          return try await context.dependency(targetName, artifact: artifact ?? .staticlib)
        case .target(target: let targetName, project: .some(let projectName), artifact: let artifact):
          guard let projectIndex = await context.projectRef(name: projectName) else {
            throw Dependency.ParsingError.unknownProject(projectName)
          }
          guard let targetIndex = await context.targetIndex(name: targetName, project: projectIndex) else {
            throw Dependency.ParsingError.unknownTarget(name: targetName, inProject: projectName)
          }
          return Dependency.library(LibraryTargetDependency(
            target: TargetRef(target: targetIndex, project: projectIndex),
            artifact: artifact ?? .staticlib
          ))
        case .pkgconfig(name: let name, preferStatic: let preferStatic):
          if preferStatic {
            fatalError("unimplemented")
          }
          return Dependency.pkgconfig(try PkgConfigDependency(name: name))
        case .system(name: let name):
          return Dependency.system(name)
      }
    }
  }

  //enum Data {
  //  case target(String)
  //  case targetAndArtifact(targetName: String, artifactType: LibraryArtifactType)
  //  case targetAndProject(targetName: String, projectName: String)
  //  case targetProjectAndArtifact(targetName: String, projectName: String, artifactType: LibraryArtifactType)
  //  case pkgconfig(String)
  //  case system(String)

  //  func resolve(_ context: borrowing Beaver) async throws -> Dependency {
  //    switch (self) {
  //      case .target(let targetName):
  //        return try await context.dependency(targetName)
  //      case .targetAndArtifact(targetName: let targetName, artifactType: let artifactType):
  //        return Dependency.library(LibraryTargetDependency(
  //          target: try await context.evaluateTarget(targetName: targetName),
  //          artifact: artifactType
  //        ))
  //      case .targetAndProject(targetName: let targetName, projectName: let projectName):
  //        guard let projectIndex = await context.projectRef(name: projectName) else {
  //          throw Dependency.ParsingError.unknownProject(projectName)
  //        }
  //        guard let targetIndex = await context.targetIndex(name: targetName, project: projectIndex) else {
  //          throw Dependency.ParsingError.unknownTarget(name: targetName, inProject: projectName)
  //        }
  //        return Dependency.library(LibraryTargetDependency(
  //          target: TargetRef(target: targetIndex, project: projectIndex),
  //          artifact: .staticlib
  //        ))
  //      case .targetProjectAndArtifact(targetName: let targetName, projectName: let projectName, artifactType: let artifactType):
  //        guard let projectIndex = await context.projectIndex(name: projectName) else {
  //          throw Dependency.ParsingError.unknownProject(projectName)
  //        }
  //        guard let targetIndex = await context.targetIndex(name: targetName, project: projectIndex) else {
  //          throw Dependency.ParsingError.unknownTarget(name: targetName, inProject: projectName)
  //        }

  //        return Dependency.library(LibraryTargetDependency(
  //          target: TargetRef(target: targetIndex, project: projectIndex),
  //          artifact: artifactType
  //        ))
  //      case .pkgconfig(let name):
  //        return Dependency.pkgconfig(name)
  //      case .system(let name):
  //        return Dependency.system(name)
  //    }
  //  }
  //}

  public init(_ value: RbObject, context: UnsafeSendable<Rc<Beaver>>) throws {
    switch (value.rubyType) {
      case .T_STRING:
        let val: String = try value.convert()
        self.data = .target(target: val, project: nil, artifact: nil)
      case .T_ARRAY:
        let arr = value.collection
        switch (arr.count) {
          case 0: throw Dependency.ParsingError.unexpectedNoComponents
          case 1...2:
            let second = arr[1]
            if let artifactType: LibraryArtifactType = try? second.convert() {
              let targetName: String = try arr[0].convert()
              self.data = .target(target: targetName, project: nil, artifact: artifactType)
            } else {
              let targetName: String = try arr[0].convert()
              let projectName: String = try second.convert()
              self.data = .target(target: targetName, project: projectName, artifact: nil)
            }
          case 3:
            let targetName: String = try arr[0].convert()
            let projectName: String = try arr[1].convert()
            let artifactType: LibraryArtifactType = try arr[2].convert()
            self.data = .target(
              target: targetName,
              project: projectName,
              artifact: artifactType
            )
          default:
            throw Dependency.ParsingError.malformed(value.description)
        }
      case .T_HASH:
        var target: String? = nil
        var project: String? = nil
        var artifact: LibraryArtifactType? = nil

        try value.call("each") { value in
          let key: String = try value[0].call("[]", args: [0]).convert()
          let val = try value[0].call("[]", args: [1])

          switch (key) {
            case "target":
              target = try val.convert()
            case "project":
              project = try val.convert()
            case "artifact":
              artifact = try val.convert()
            default:
              throw Dependency.ParsingError.malformed(value.description)
          }

          return RbObject.nilObject
        }

        self.data = .target(target: target!, project: project, artifact: artifact)
      case .T_STRUCT:
        //let inner: DependencyFuture = try value.call("inner").convert(to: Result<DependencyFuture, any Error>.self).get()
        let inner = try DependencyFuture(try value.call("inner"), context: context)
        let artifact: LibraryArtifactType? = try value.call("artifact").convert()

        switch (inner.data) {
          case .target(target: let target, project: let project, artifact: _):
            self.data = .target(target: target, project: project, artifact: artifact ?? .staticlib)
          case .pkgconfig(name: let name, preferStatic: _):
            self.data = .pkgconfig(name: name, preferStatic: artifact == .staticlib)
          case .system(name: _):
            throw Dependency.ParsingError.malformed(value.description)
        }
      case .T_BIGNUM: fallthrough
      case .T_FIXNUM:
        self.data = Self.registered[try value.convert(to: Int.self)]
      default:
        throw Dependency.ParsingError.malformed(value.description)
    }
  }

  public func resolve(context: borrowing Beaver) async throws -> Dependency {
    try await self.data.resolve(context)
  }
}

fileprivate extension Collection {
  func containsAll<C: RangeReplaceableCollection>(_ other: C) -> Bool
  where
    Self.Element: Equatable,
    C.Element == Self.Element
  {
    var elems = other
    for elem in self {
      if let index = elems.firstIndex(where: { $0 == elem }) {
        elems.remove(at: index)
        if elems.count == 0 {
          return true
        }
      }
    }
    return false
  }
}

extension Array<DependencyFuture> {
  public init(_ value: RbObject, context: UnsafeSendable<Rc<Beaver>>) throws {
    switch (value.rubyType) {
      case .T_ARRAY:
        self = try value.collection.map { rbObj in
          try DependencyFuture(rbObj, context: context)
        }
      default:
        self = [try DependencyFuture(value, context: context)]
    }
  }
}
