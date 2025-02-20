import Foundation
import Utils
import timespec
import Glob
import Platform

public struct CMakeImporter {
  public static func `import`(
    baseDir: URL,
    buildDir: URL,
    cmakeFlags: [String],
    makeFlags: [String],
    context: inout Beaver
  ) async throws {
    try context.requireBuildDir()

    //let buildDir = buildDir.appending(path: context.optimizeMode.description)
    let buildDirExists = FileManager.default.exists(at: buildDir)
    if !buildDirExists {
      try FileManager.default.createDirectory(at: buildDir, withIntermediateDirectories: true)
    }

    let apiDir = buildDir.appending(path: ".cmake/api/v1")
    let replyDir = apiDir.appending(path: "reply")

    let queryDir = apiDir.appending(path: "query")
    let queryDirExists = FileManager.default.exists(at: queryDir)
    if !queryDirExists {
      try FileManager.default.createDirectory(at: queryDir, withIntermediateDirectories: true)
    }
    let codemodelRequest = queryDir.appending(path: "codemodel-v2")
    if !FileManager.default.exists(at: codemodelRequest) {
      try FileManager.default.createFile(at: codemodelRequest)
    }
    let cmakeFilesRequest = queryDir.appending(path: "cmakeFiles-v1")
    if !FileManager.default.exists(at: cmakeFilesRequest) {
      try FileManager.default.createFile(at: cmakeFilesRequest)
    }

    let reconfigure = try context.cache!.shouldReconfigureCMakeProject(baseDir)
    let cmakeReconfigured = reconfigure || !buildDirExists || !queryDirExists || !FileManager.default.exists(at: replyDir)
    if cmakeReconfigured {
      try await Tools.exec(
        Tools.cmake!,
        [
          baseDir.absoluteURL.path,
          "-DCMAKE_BUILD_TYPE=\(context.optimizeMode.cmakeDescription)",
          "-G", "Ninja"
        ] + cmakeFlags,
        baseDir: buildDir
      )
    }

    let cmakeIndexPaths = try await Glob.search(
      directory: replyDir,
      include: [Glob.Pattern("index-*.json")]
    ).reduce(into: [URL](), { $0.append($1) })

    let cmakeIndexPath: URL? = if cmakeIndexPaths.count <= 1 {
      cmakeIndexPaths.first
    } else {
      try cmakeIndexPaths
        .map { (url: URL) in
          (url, try FileChecker.fileAttrs(file: url).st_mtimespec)
        }.reduce(into: (URL, timespec)?(nil)) { (acc: inout (URL, timespec)?, c: (URL, timespec)) in
          guard let _acc = acc else {
            acc = c
            return
          }
          let currentmtime: timespec = c.1
          let highestmtime: timespec = _acc.1
          if timespec_gt(highestmtime, currentmtime) {
            acc = c
          }
        }?.0
    }

    if cmakeIndexPath == nil {
      throw CMakeImportError.queryFailed
    }

    let cmakeIndexData = try Data(contentsOf: cmakeIndexPath!)
    let cmakeIndex: CMakeIndexV1
    switch (Result(try JSONDecoder().decode(CMakeIndexV1.self, from: cmakeIndexData))) {
      case .success(let val): cmakeIndex = val
      case .failure(let error):
        if !(error is DecodingError) { throw error }
        throw CMakeImportError.jsonDecodingError(
          error: error as! DecodingError,
          whileParsing: "index",
          at: cmakeIndexPath!
        )
    }

    // Determine targets
    let codemodelPath = replyDir.appending(path: cmakeIndex.codemodel!.path)
    let codemodelData = try Data(contentsOf: codemodelPath)
    let codemodel: CMakeCodeModelV2
    switch (Result(try JSONDecoder().decode(CMakeCodeModelV2.self, from: codemodelData))) {
      case .success(let val): codemodel = val
      case .failure(let error):
        if !(error is DecodingError) { throw error }
        throw CMakeImportError.jsonDecodingError(
          error: error as! DecodingError,
          whileParsing: "codemodel",
          at: codemodelPath
        )
    }

    if cmakeReconfigured {
      // Determine if needs to be reconfigured based on these files
      let cmakeFilesPath = replyDir.appending(path: cmakeIndex.cmakeFiles!.path)
      let cmakeFilesData = try Data(contentsOf: cmakeFilesPath)
      let cmakeFiles: CMakeFilesV1
      switch (Result(try JSONDecoder().decode(CMakeFilesV1.self, from: cmakeFilesData))) {
        case .success(let val): cmakeFiles = val
        case .failure(let error):
          if !(error is DecodingError) { throw error }
          throw CMakeImportError.jsonDecodingError(
            error: error as! DecodingError,
            whileParsing: "cmakefiles",
            at: cmakeFilesPath
          )
      }

      if let inputs = cmakeFiles.inputs {
        try context.cache!.storeCMakeFiles(dir: baseDir, inputs.map { input in
          if input.path.starts(with: "/") {
            URL(filePath: input.path)
          } else {
            baseDir.appending(path: input.path)
          }
        })
      }
    }

    let cmakeConfiguration = codemodel.configurations.first!

    for project in cmakeConfiguration.projects {
      var targets = NonCopyableArray<AnyTarget>()

      if let targetIndexes = project.targetIndexes {
        for index in targetIndexes {
          let targetFile = replyDir.appending(path: cmakeConfiguration.targets[index].jsonFile)
          let targetData = try Data(contentsOf: targetFile)
          let target: CMakeTargetV2
          switch (Result(try JSONDecoder().decode(CMakeTargetV2.self, from: targetData))) {
            case .success(let val): target = val
            case .failure(let error):
              if !(error is DecodingError) { throw error }
              throw CMakeImportError.jsonDecodingError(
                error: error as! DecodingError,
                whileParsing: "target",
                at: targetFile
              )
          }
//          let flagsInclude = context.config.cmake.flagsInclude
          let addLibrary = { (artifactType: LibraryArtifactType, targets: inout NonCopyableArray<AnyTarget>) in
            if (target.artifacts?.count != 1) {
              if (target.artifacts == nil || target.artifacts?.count == 0) {
                MessageHandler.warn("\(target.name) is not imported because it has no artifacts")
              } else if ((target.artifacts?.count ?? 99) > 1) {
                MessageHandler.warn("\(target.name) is not imported because it has multiple artifacts. Please open an issue on GitHub (artifacts are \(target.artifacts!))")
              }
            }
            let cflags: [String] = target.compileGroups?.flatMap({ compileGroup in
              var cflags: [String] = []
//              if flagsInclude.compileCommandFragments {
//                if let f = compileGroup.compileCommandFragments?.flatMap({ Tools.parseArgs($0.fragment).map { String($0) } }) {
//                  cflags.append(contentsOf: f)
//                }
//              }
//              if flagsInclude.defines {
                if let f = (compileGroup.defines?.map { "-D\($0.define)" }) {
                  cflags.append(contentsOf: f)
                }
//              }
              if let f = (compileGroup.includes?.map { "-I\($0.path)" }) {
                cflags.append(contentsOf: f)
              }
              return cflags
            }) ?? []
            let path = target.artifacts!.first!.path
            targets.append(.library(.cmake(CMakeLibrary(
              cmakeId: target.id,
              name: target.name,
              language: target.link == nil ? .c : Language(fromCMake: target.link!.language)!,
              id: targets.count,
              artifact: artifactType,
              artifactURL: path.first == "/" ? URL(filePath: path) : buildDir.appending(path: path),
              linkerFlags: target.link?.commandFragments.flatMap { fragment in
                Tools.parseArgs(fragment.fragment).map { String($0) }
              } ?? [],
              cflags: cflags,
              dependencies: target.dependencies?.map { dep in Dependency.cmakeId(dep.id) } ?? []
            ))))
          }
          switch (target.type) {
            case "STATIC_LIBRARY":
              addLibrary(.staticlib, &targets)
            case "SHARED_LIBRARY":
              addLibrary(.dynlib, &targets)
            case "EXECUTABLE":
              if (target.artifacts?.count != 1) {
                if (target.artifacts == nil || target.artifacts?.count == 0) {
                  MessageHandler.warn("\(target.name) is not imported because it has no artifacts")
                } else if ((target.artifacts?.count ?? 99) > 1) {
                  MessageHandler.warn("\(target.name) is not imported because it has multiple artifacts. Please open an issue on GitHub (artifacts are \(target.artifacts!))")
                }
              }
              let path = target.artifacts!.first!.path
              targets.append(.executable(.cmake(CMakeExecutable(
                cmakeId: target.id,
                name: target.name,
                language: target.link == nil ? .c : Language(fromCMake: target.link!.language)!,
                id: targets.count,
                artifact: .executable,
                artifactURL: path.first == "/" ? URL(filePath: path) : buildDir.appending(path: path),
                dependencies: target.dependencies?.map { dep in Dependency.cmakeId(dep.id) } ?? []
              ))))
            default:
              if cmakeReconfigured {
                MessageHandler.warn("CMake target type '\(target.type)' is currently not supported")
              }
              continue
          }
        }
      }

      await context.addProject(.cmake(CMakeProject(
        name: project.name,
        baseDir: baseDir,
        buildDir: buildDir,
        makeFlags: makeFlags,
        targets: targets
      )))
    }
  }
}

enum CMakeImportError: Error {
  case queryFailed
  case jsonDecodingError(
    error: DecodingError,
    whileParsing: String,
    at: URL
  )
}

extension CMakeImportError: CustomStringConvertible {
  private static func formatPath(_ path: [any CodingKey]) -> String {
    path.map { key in
      if let intValue = key.intValue {
        "[\(intValue)]"
      } else {
        ".\(key.stringValue)"
      }
    }.joined(separator: "")
  }

  private static func formatContext(errorName: String, _ context: DecodingError.Context) -> String {
    var ret = """
      \(errorName): \(context.debugDescription)
      Path: \(Self.formatPath(context.codingPath))
    """
    if let underlyingError = context.underlyingError {
      ret += "  UnderlyingError: \(underlyingError)"
    }
    return ret
  }

  public var description: String {
    switch (self) {
      case .queryFailed: return "Error importing CMake: query failed"
      case .jsonDecodingError(error: let decodingError, whileParsing: let objectName, at: let file):
        var desc = "Error importing CMake: JSONParsingError occured while parsing \(objectName) (at: \(file.path))\n"
        switch (decodingError) {
          case .dataCorrupted(let context):
            desc += Self.formatContext(errorName: "DataCorrupted", context)
          case .keyNotFound(_, let context):
            desc += Self.formatContext(errorName: "KeyNotFound", context)
          case .typeMismatch(_, let context):
            desc += Self.formatContext(errorName: "TypeMismatch", context)
          case .valueNotFound(_, let context):
            desc += Self.formatContext(errorName: "ValueNotFound", context)
          default:
            desc += "\(decodingError)"
        }
        return desc
    }
  }
}
