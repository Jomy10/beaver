import Foundation
import Beaver
import RubyGateway
import Utils
import Atomics

func collectArgs(_ rbArgs: [RbObject]) throws -> [String] {
  let args: [String] = try rbArgs
    .map { try $0.convert(to: String.self) }
    .map { arg in
      if arg.count == 1 {
        "-\(arg)"
      } else {
        "--\(arg)"
      }
    }
  if args.count == 0 {
    throw CommandLineError.noArgs
  }
  return args
}

func loadCommandLineMethods<Args: Collection & BidirectionalCollection & Sendable>(
  in module: RbObject,
  args: RWLock<MutableDiscontiguousSlice<Args>>,
  queue: SyncTaskQueue,
  context: Beaver
) throws
  where Args.Element == String
{
  try module.defineMethod(
    "opt",
    argsSpec: RbMethodArgsSpec(
      supportsSplat: true,
      optionalKeywordValues: ["default": RbObject.nilObject]
    ),
    body: { obj, method in
      let argSpec = try collectArgs(method.args.splatted)
      let defaultArg = method.args.keyword["default"]!

      return try args.write { slice in
        if let index = slice.firstIndex(where: { argSpec.contains($0) }) {
          let valueIndex = slice.index(after: index)
          let val = slice[valueIndex]
          slice.removeSubrange(index..<slice.index(after: valueIndex))
          return RbObject(val)
        } else {
          return defaultArg
        }
      }
    }
  )

  try module.defineMethod(
    "flag",
    argsSpec: RbMethodArgsSpec(
      supportsSplat: true,
      optionalKeywordValues: ["default": RbObject(false)]
    ),
    body: { obj, method in
      let argSpec = try collectArgs(method.args.splatted)
      let defaultArg = method.args.keyword["default"]!

      return try args.write { slice in
        if let index = slice.firstIndex(where: { argSpec.contains($0) }) {
          let endIndex = slice.index(after: index)
          slice.removeSubrange(index..<endIndex)
          return RbObject(true)
        } else if defaultArg.isNil || defaultArg.isTruthy {
          let negativeArgSpec: [String] = argSpec
            .compactMap { arg in
              if arg.starts(with: "--") {
                let idx = arg.index(arg.startIndex, offsetBy: 2)
                return arg[arg.startIndex..<idx] + "no-" + arg[idx..<arg.endIndex]
              } else {
                return nil
              }
            }
          if let index = slice.firstIndex(where: { negativeArgSpec.contains($0) }) {
            let endIndex = slice.index(after: index)
            slice.removeSubrange(index..<endIndex)
            return RbObject(false)
          } else {
            return defaultArg
          }
        } else {
          return defaultArg
        }
      }
    }
  )

  try module.defineMethod(
    "cmd",
    argsSpec: RbMethodArgsSpec(
      leadingMandatoryCount: 1,
      optionalKeywordValues: ["overwrite": RbObject(false)],
      requiresBlock: true
    ),
    body: { obj, method in
      let commandName: String = try method.args.mandatory[0].convert()
      let overwrite: Bool = try method.args.keyword["overwrite"]!.convert()
      let callback = try method.captureBlock()

      let command: Commands.Command = { context in
        try await MainActor.run {
          _ = try callback.call("call")
        }
      }

      queue.addTask {
        try await context.addCommand(commandName, overwrite: overwrite, command)
      }

      return RbObject.nilObject
    }
  )
}
