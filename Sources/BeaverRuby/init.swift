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

  // Define C Target Functions //
  let cModule = try Ruby.defineModule("C")
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

  try Ruby.require(filename: URL(filePath: "lib/lib.rb").absoluteURL.path)
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
    guard let project = context.value.withInner({ (ctx: borrowing Beaver) in
      ctx.currentProjectIndex
    }) else {
      throw Beaver.ProjectAccessError.noDefaultProject
    }
    let args = try cTargetParseRubyArgs(rubyArgs: rubyArgs, context: context, artifactType: LibraryArtifactType.self)
    queue.addTask({
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
    guard let project = context.value.withInner({ (ctx: borrowing Beaver) in
      ctx.currentProjectIndex
    }) else {
      throw Beaver.ProjectAccessError.noDefaultProject
    }
    let args = try cTargetParseRubyArgs(rubyArgs: rubyArgs, context: context, artifactType: ExecutableArtifactType.self)
    queue.addTask({
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

enum RbConversionError: Error, @unchecked Sendable {
  case incompatible(from: RbType, to: Any.Type)
  /// An unexpected key was found in a hash
  case unexpectedKey(key: String, type: Any.Type)
  /// Expected a key in a hash to be present, but did not find the key
  case keyNotFound(key: String, type: Any.Type)
  case unknownError
}
