import Foundation
import Beaver
import RubyGateway
import Utils

fileprivate func cTargetParseRubyArgs<ArtifactType: RbObjectConvertible & ArtifactTypeProtocol>(
  rubyArgs: borrowing [String: RbObject],
  context: UnsafeSendable<Rc<Beaver>>,
  artifactType: ArtifactType.Type
) throws -> (
  name: String,
  description: String?,
  version: Version?,
  homepage: URL?,
  license: String?,
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
  let licenseArg = rubyArgs["license"]!
  let languageArg = rubyArgs["language"]!
  let artifactsArg = rubyArgs["artifacts"]!
  let dependenciesArg = rubyArgs["dependencies"]!
  let headersArg = rubyArgs["headers"]!
  let cflagsArg = rubyArgs["cflags"]!
  let linkerFlagsArg = rubyArgs["linkerFlags"]!
  let sourcesArgs = rubyArgs["sources"]!

  return (
    name: try rubyArgs["name"]!.convert(),
    description: desc.isNil ? nil : try desc.convert(),
    version: versionArg.isNil ? nil : try versionArg.convert(),
    homepage: homepageArg.isNil ? nil : try homepageArg.convert(),
    license: licenseArg.isNil ? nil : try licenseArg.convert(),
    language: languageArg.isNil ? .c : try languageArg.convert(),
    artifacts: artifactsArg.isNil ? nil : try artifactsArg.convert(),
    dependencies: dependenciesArg.isNil
      ? Array<DependencyFuture>()
      : try Array<DependencyFuture>(dependenciesArg, context: context),
    sources: try sourcesArgs.convert(to: Result<Files, any Error>.self).get(),
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
        license: args.license,
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

func loadCMethods(in module: RbObject, queue: SyncTaskQueue, context: UnsafeSendable<Rc<Beaver>>) throws {
  let mandatory = Set(["name", "sources"])
  let optional: [String: any RbObjectConvertible & Sendable] = [
    "description": RbObject.nilObject,
    "homepage": RbObject.nilObject,
    "version": RbObject.nilObject,
    "license": RbObject.nilObject,
    "language": Language.c,
    "headers": RbObject.nilObject,
    "cflags": RbObject.nilObject,
    "linkerFlags": RbObject.nilObject,
    "artifacts": RbObject.nilObject,
    "dependencies": RbObject.nilObject
  ]

  let cModule = try Ruby.defineModule("C", under: module)
  try cModule.defineSingletonMethod(
    "Library",
    argsSpec: RbMethodArgsSpec(
      mandatoryKeywords: mandatory,
      optionalKeywordValues: optional
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
      mandatoryKeywords: mandatory,
      optionalKeywordValues: optional
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
}
