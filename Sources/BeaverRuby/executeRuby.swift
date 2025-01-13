import Foundation
import Beaver
import RubyGateway
import Utils
import AsyncAlgorithms
import Atomics

/// Initializes ruby environment and executes the given script file
public func executeRuby(
  scriptFile: URL,
  context: UnsafeSendable<Rc<Beaver>>
) throws -> SyncTaskQueue {
  let scriptContents = try String(contentsOf: scriptFile, encoding: .utf8)
  let queue: SyncTaskQueue = SyncTaskQueue()

  // TODO: also allow shorthand Library("name")
  let beaverModule = try Ruby.defineModule("Beaver")
  try beaverModule.defineMethod(
    "Project",
    argsSpec: RbMethodArgsSpec(
      mandatoryKeywords: Set(
        Project.arguments
          .filter { $0.mandatory }
          .map { $0.name }
      ),
      optionalKeywordValues: Dictionary(uniqueKeysWithValues:
        Project.arguments
          .filter { !$0.mandatory }
          .map { ($0.name, nil) }
      )
    ),
    body: { (obj: RbObject, method: RbMethod) throws -> RbObject in
      let proj = UnsafeSendable(Rc(try context.value.withInner { (context: borrowing Beaver) in
        try Project(method.args.keyword, context: context)
      }))
      queue.addTask { [proj = consume proj] in
        await context.value.withInner { (context: inout Beaver) in
          _ = await context.addProject(proj.value.take()!)
        }
      }
      return RbObject.nilObject
    }
  )

  // Define C Target Functions //
  let cModule = try Ruby.defineModule("C", under: beaverModule)
  try cModule.defineSingletonMethod(
    "Library",
    argsSpec: RbMethodArgsSpec(
      mandatoryKeywords: Set(
        CLibrary.arguments
          .filter { $0.mandatory }
          .map { $0.name }
      ),
      optionalKeywordValues: Dictionary(uniqueKeysWithValues:
        CLibrary.arguments
          .filter { !$0.mandatory }
          .map { ($0.name, nil) }
      )
    ),
    body: { (obj, method) in
      try CLibrary.asyncInitAdd(
        rubyArgs: method.args.keyword,
        queue: queue,
        context: context)
      return RbObject.nilObject
    }
  )
  try cModule.defineSingletonMethod(
    "Executable",
    argsSpec: RbMethodArgsSpec(
      mandatoryKeywords: Set(
        CExecutable.arguments
          .filter { $0.mandatory }
          .map { $0.name }
      ),
      optionalKeywordValues: Dictionary(uniqueKeysWithValues:
        CExecutable.arguments
          .filter { !$0.mandatory }
          .map { ($0.name, nil) }
      )
    ),
    body: { (obj, method) in
      try CExecutable.asyncInitAdd(
        rubyArgs: method.args.keyword,
        queue: queue,
        context: context
      )
      return RbObject.nilObject
    }
  )

  let libFilePath = Bundle.module.path(forResource: "lib", ofType: "rb", inDirectory: "lib")!
  try Ruby.require(filename: libFilePath)
  try Ruby.eval(ruby: scriptContents)
  return queue
}

func cTargetParseRubyArgs<ArtifactType: RbObjectConvertible & ArtifactTypeProtocol>(
  rubyArgs: borrowing [String: RbObject],
  context: UnsafeSendable<Rc<Beaver>>,
  artifactType: ArtifactType.Type
) throws -> (
  name: String,
  description: String?,
  version: Version?,
  homepage: URL?,
  language: Language,
  artifacts: [ArtifactType]?,
  dependencies: [DependencyFuture],
  sources: Files,
  headers: Headers,
  cflags: Flags,
  linkerFlags: [String]
) {
  let desc = rubyArgs["description"]!
  let versionArg = rubyArgs["version"]!
  let homepageArg = rubyArgs["homepage"]!
  let languageArg = rubyArgs["language"]!
  let artifactsArg = rubyArgs["artifacts"]!
  let dependenciesArg = rubyArgs["dependencies"]!
  let headersArg = rubyArgs["headers"]!
  let cflagsArg = rubyArgs["cflags"]!
  let linkerFlagsArg = rubyArgs["linkerFlags"]!

  return (
    name: try rubyArgs["name"]!.convert(),
    description: desc.isNil ? nil : try desc.convert(),
    version: versionArg.isNil ? nil : try versionArg.convert(),
    homepage: homepageArg.isNil ? nil : try homepageArg.convert(),
    language: languageArg.isNil ? .c : try languageArg.convert(),
    artifacts: artifactsArg.isNil ? nil : try artifactsArg.convert(),
    dependencies: dependenciesArg.isNil
      ? Array<DependencyFuture>()
      : try Array<DependencyFuture>(dependenciesArg, context: context),
    sources: try rubyArgs["sources"]!.convert(to: Result<Files, any Error>.self).get(),
    headers: headersArg.isNil ? Headers() : try Headers(headersArg),
    cflags: cflagsArg.isNil ? Flags() : try cflagsArg.convert(),
    linkerFlags: linkerFlagsArg.isNil ? [] : try linkerFlagsArg.convert()
  )
}

extension CLibrary {
  static func asyncInitAdd(
    rubyArgs: borrowing [String: RbObject],
    queue: SyncTaskQueue,
    context: UnsafeSendable<Rc<Beaver>>
  ) throws {
    let args = try cTargetParseRubyArgs(rubyArgs: rubyArgs, context: context, artifactType: LibraryArtifactType.self)
    queue.addTask({
      guard let project = context.value.withInner({ (ctx: borrowing Beaver) in
        ctx.currentProjectIndex
      }) else {
        throw Beaver.ProjectAccessError.noDefaultProject
      }

      let lib = try CLibrary.init(
        name: args.name,
        description: args.description,
        version: args.version,
        homepage: args.homepage,
        language: args.language,
        artifacts: args.artifacts ?? CLibrary.defaultArtifacts,
        sources: args.sources,
        headers: args.headers,
        cflags: args.cflags,
        linkerFlags: args.linkerFlags,
        dependencies: try await args.dependencies.async
          .map { future in try await context.value.withInner { (ctx: borrowing Beaver) in try await future.resolve(context: ctx) } }
          .reduce(into: [], { (arr, elem) in arr.append(elem) })
      )

      await context.value.withInner { (ctx: inout Beaver) in
        await ctx.withProject(project) { (proj: inout Project) in
          _ = await proj.addTarget(lib)
        }
      }
    })
  }
}

extension CExecutable {
  static func asyncInitAdd(
    rubyArgs: borrowing [String: RbObject],
    queue: SyncTaskQueue,
    context: UnsafeSendable<Rc<Beaver>>
  ) throws {
    let args = try cTargetParseRubyArgs(rubyArgs: rubyArgs, context: context, artifactType: ExecutableArtifactType.self)
    queue.addTask({
      guard let project = context.value.withInner({ (ctx: borrowing Beaver) in
        ctx.currentProjectIndex
      }) else {
        throw Beaver.ProjectAccessError.noDefaultProject
      }

      let lib = try CExecutable.init(
        name: args.name,
        description: args.description,
        version: args.version,
        homepage: args.homepage,
        language: args.language,
        artifacts: args.artifacts ?? CExecutable.defaultArtifacts,
        sources: args.sources,
        headers: args.headers,
        cflags: args.cflags,
        linkerFlags: args.linkerFlags,
        dependencies: try await args.dependencies.async
          .map { future in try await context.value.withInner { (ctx: borrowing Beaver) in try await future.resolve(context: ctx) } }
          .reduce(into: [], { (arr, elem) in arr.append(elem) })
      )

      await context.value.withInner { (ctx: inout Beaver) in
        await ctx.withProject(project) { (proj: inout Project) in
          _ = await proj.addTarget(lib)
        }
      }
    })
  }
}

extension Project {
  init(
    _ args: borrowing [String: RbObject],
    context: borrowing Beaver
  ) throws {
    let name: String = try args["name"]!.convert()
    let baseDirArg = args["baseDir"]!
    let baseDir: URL = baseDirArg.isNil ? URL.currentDirectory() : URL(filePath: try baseDirArg.convert(to: String.self))
    let buildDirArg = args["buildDir"]!
    let buildDir: URL = buildDirArg.isNil ? URL.currentDirectory().appending(path: ".build") : URL(filePath: try buildDirArg.convert(to: String.self))

    self = Self.init(
      name: name,
      baseDir: baseDir,
      buildDir: buildDir,
      context: context
    )
  }
}

enum RbConversionError: Error, @unchecked Sendable {
  case incompatible(from: RbType, to: Any.Type)
  /// An unexpected key was found in a hash
  case unexpectedKey(key: String, type: Any.Type)
  /// Expected a key in a hash to be present, but did not find the key
  case keyNotFound(key: String, type: Any.Type)
  case unknownError
}
