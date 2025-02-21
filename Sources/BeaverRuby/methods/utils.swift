import Foundation
import RubyGateway
import Beaver
import Utils

fileprivate struct ShError: Error {
  let message: String

  init(_ message: String) {
    self.message = message
  }
}

enum CacheVarError: Error {
  case invalidValueType(UnsafeSendable<RbType>)
}

func loadUtilsMethods(in module: RbObject, queue: SyncTaskQueue, asyncQueue: AsyncTaskQueue, context: Beaver) throws {
  // Async -> method should be waited on in Ruby
  // Sync -> Runs on the sync task queue
  try module.defineMethod(
    "_buildDirAsyncSync",
    argsSpec: RbMethodArgsSpec(
      leadingMandatoryCount: 1
    ),
    body: { obj, method in
      let dir: String = try method.args.mandatory[0].convert()
      let signal = RbSignalOneshot()
      queue.addTask {
        do {
          try await context.setBuildDir(URL(filePath: dir))
          signal.complete()
        } catch let error {
          signal.fail(error)
        }
      }

      return RbObject(signal)
    }
  )

  // Returns true if the file with the specific context was changed, false if not and nil
  // if the file doesn't exist
  try module.defineMethod(
    "_fileChangedWithContextAsyncAsync",
    argsSpec: RbMethodArgsSpec(
      leadingMandatoryCount: 2
    ),
    body: { obj, method in
      let filename: String = try method.args.mandatory[0].convert()
      let fileContext: String = try method.args.mandatory[1].convert()

      let file = URL(filePath: filename)
      let promise = RbPromise()

      asyncQueue.addTask {
        do {
          if !FileManager.default.exists(at: file) {
            promise.resolve(RbObject.nilObject)
          }

          let obj = RbObject(try await context.fileChanged(file, context: fileContext))
          promise.resolve(obj)
        } catch let error {
          promise.fail(error)
        }
      }

      return RbObject(promise)
    }
  )

  try module.defineMethod(
    "_cacheAsyncAsync",
    argsSpec: RbMethodArgsSpec(
      leadingMandatoryCount: 1,
      optionalValues: [RbObject(RbSymbol("get"))]
    ),
    body: { boy, method in
      let contextName: String = try method.args.mandatory[0].convert(to: String.self)
      let contextString: String = if let idx = context.currentProjectIndex {
        context.unsafeProjectName(idx) + ":" + contextName
      } else {
        contextName
      }
      let promise = RbPromise()

      asyncQueue.addTask {
        let valArg = method.args.optional[0]
        let obj: RbObject
        do {
          if try valArg.call("==", args: [RbSymbol("get")]).convert(to: Bool.self) {
            switch (try await context.cacheGetVar(context: contextString)) {
              case .string(let s): obj = RbObject(s)
              case .int(let i): obj = RbObject(i)
              case .double(let d): obj = RbObject(d)
              case .bool(let b): obj = RbObject(b)
              case .none: obj = RbObject.nilObject
            }
          } else {
            switch (valArg.rubyType) {
              case .T_STRING: fallthrough
              case .T_SYMBOL:
                let val = try valArg.convert(to: String.self)
                try await context.cacheSetVar(context: contextString, value: val)
              case .T_BIGNUM: fallthrough
              case .T_FIXNUM:
                let val = try valArg.convert(to: Int.self)
                try await context.cacheSetVar(context: contextString, value: val)
              case .T_FLOAT:
                let val = try valArg.convert(to: Double.self)
                try await context.cacheSetVar(context: contextString, value: val)
              case .T_TRUE: fallthrough
              case .T_FALSE:
                let val = try valArg.convert(to: Bool.self)
                try await context.cacheSetVar(context: contextString, value: val)
              case .T_NIL:
                try await context.cacheSetVar(context: contextString, value: .none)
              default:
                throw CacheVarError.invalidValueType(UnsafeSendable(valArg.rubyType))
            }
            obj = RbObject.nilObject
          }
          promise.resolve(obj)
        } catch let error {
          promise.fail(error)
        }
      }

      return RbObject(promise)
    }
  )

  try module.defineMethod(
    "_shAsyncSync",
    argsSpec: RbMethodArgsSpec(
      supportsSplat: true
    ),
    body: { obj, method in
      let cmd: [String] = try method.args.splatted.map { try $0.convert(to: String.self) }
      let signal = RbSignalOneshot()

      if cmd.count == 0 {
        throw ShError("no arguments")
      } else if cmd.count == 1 {
        queue.addTask {
          do {
            try await Tools.exec(Tools.sh!, ["-c", cmd.first!])
            signal.complete()
          } catch let error {
            signal.fail(error)
          }
        }
      } else {
        guard let cmdName = Tools.which(cmd[cmd.startIndex]) else {
          throw ShError("Executable named \(cmd[cmd.startIndex]) not found")
        }
        let arguments = cmd[cmd.index(after: cmd.startIndex)...]
        queue.addTask {
          do {
            try await Tools.exec(cmdName, Array(arguments))
            signal.complete()
          } catch let error {
            signal.fail(error)
          }
        }
      }

      return RbObject(signal)
    }
  )

  //try module.defineMethod(
  //  "shOnceAsync",
  //  argsSpec: RbMethodArgsSpec(
  //    supportsSplat: true,

  //  )
  //)

  try module.defineMethod(
    "getArgs",
    argsSpec: RbMethodArgsSpec(
      leadingMandatoryCount: 1
    ),
    body: { obj, method in
      let argsString = try method.args.mandatory[0].convert(to: String.self)
      let parsedArgs = Tools.parseArgs(argsString)
      return RbObject(parsedArgs.map { RbObject(String($0)) })
    }
  )
}
