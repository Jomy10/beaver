import Beaver
import RubyGateway
import Utils

struct DependencyFuture {
  let data: Data

  enum Data {
    case target(String)
    case targetAndArtifact(targetName: String, artifactType: LibraryArtifactType)
    case targetAndProject(targetName: String, projectName: String)
    case targetProjectAndArtifact(targetName: String, projectName: String, artifactType: LibraryArtifactType)
    case pkgconfig(String)
    case system(String)

    func resolve(_ context: borrowing Beaver) async throws -> Dependency {
      switch (self) {
        case .target(let targetName):
          return try await context.dependency(targetName)
        case .targetAndArtifact(targetName: let targetName, artifactType: let artifactType):
          return Dependency.library(LibraryTargetDependency(
            target: try await context.evaluateTarget(targetName: targetName),
            artifact: artifactType
          ))
        case .targetAndProject(targetName: let targetName, projectName: let projectName):
          guard let projectIndex = await context.projectRef(name: projectName) else {
            throw Dependency.ParsingError.unknownProject(projectName)
          }
          guard let targetIndex = await context.targetIndex(name: targetName, project: projectIndex) else {
            throw Dependency.ParsingError.unknownTarget(name: targetName, inProject: projectName)
          }
          return Dependency.library(LibraryTargetDependency(
            target: TargetRef(target: targetIndex, project: projectIndex),
            artifact: .staticlib
          ))
        case .targetProjectAndArtifact(targetName: let targetName, projectName: let projectName, artifactType: let artifactType):
          guard let projectIndex = await context.projectIndex(name: projectName) else {
            throw Dependency.ParsingError.unknownProject(projectName)
          }
          guard let targetIndex = await context.targetIndex(name: targetName, project: projectIndex) else {
            throw Dependency.ParsingError.unknownTarget(name: targetName, inProject: projectName)
          }

          return Dependency.library(LibraryTargetDependency(
            target: TargetRef(target: targetIndex, project: projectIndex),
            artifact: artifactType
          ))
        case .pkgconfig(let name):
          return Dependency.pkgconfig(name)
        case .system(let name):
          return Dependency.system(name)
      }
    }
  }

  public init(_ value: RbObject, context: UnsafeSendable<Rc<Beaver>>) throws {
    switch (value.rubyType) {
      case .T_STRING:
        let val: String = try value.convert()
        self.data = .target(val)
      case .T_ARRAY:
        let arr = value.collection
        switch (arr.count) {
          case 0: throw Dependency.ParsingError.unexpectedNoComponents
          case 1...2:
            let second = arr[1]
            if let artifactType: LibraryArtifactType = try? second.convert() {
              let targetName: String = try arr[0].convert()
              self.data = .targetAndArtifact(targetName: targetName, artifactType: artifactType)
            } else {
              let targetName: String = try arr[0].convert()
              let projectName: String = try second.convert()
              self.data = .targetAndProject(targetName: targetName, projectName: projectName)
            }
          case 3:
            let targetName: String = try arr[0].convert()
            let projectName: String = try arr[1].convert()
            let artifactType: LibraryArtifactType = try arr[2].convert()
            self.data = .targetProjectAndArtifact(
              targetName: targetName,
              projectName: projectName,
              artifactType: artifactType
            )
          default:
            throw Dependency.ParsingError.malformed(value.description)
        }
      case .T_HASH:
        guard let hash = Dictionary<String, RbObject>(value) else {
          throw Dependency.ParsingError.malformed(value.description)
        }
        let keys = hash.keys
        switch (keys.count) {
          case 0: throw Dependency.ParsingError.unexpectedNoComponents
          case 1:
            guard let targetName = hash["target"] else {
              throw Dependency.ParsingError.malformed(value.description)
            }
            self.data = .target(try targetName.convert())
          case 2:
            if keys.containsAll(["target", "project"]) {
              self.data = .targetAndProject(targetName: try hash["target"]!.convert(), projectName: try hash["projectName!"]!.convert())
            } else if keys.containsAll(["target", "artifact"]) {
              self.data = .targetAndArtifact(targetName: try hash["target"]!.convert(), artifactType: try hash["artifact"]!.convert())
            } else {
              throw Dependency.ParsingError.malformed(value.description)
            }
          case 3:
            guard let target = hash["target"] else {
              throw Dependency.ParsingError.malformed(value.description)
            }
            guard let project = hash["project"] else {
              throw Dependency.ParsingError.malformed(value.description)
            }
            guard let artifact = hash["artifact"] else {
              throw Dependency.ParsingError.malformed(value.description)
            }
            self.data = .targetProjectAndArtifact(
              targetName: try target.convert(),
              projectName: try project.convert(),
              artifactType: try artifact.convert()
            )
          default:
            throw Dependency.ParsingError.malformed(value.description)
        }
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
