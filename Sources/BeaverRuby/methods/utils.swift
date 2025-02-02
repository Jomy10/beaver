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

func loadUtilsMethods(in module: RbObject, queue: SyncTaskQueue, context: UnsafeSendable<Rc<Beaver>>) throws {
  try module.defineMethod(
    "buildDir",
    argsSpec: RbMethodArgsSpec(
      leadingMandatoryCount: 1
    ),
    body: { obj, method in
      let dir: String = try method.args.mandatory[0].convert()
      try context.value.withInner { (context: inout Beaver) in
        try context.setBuildDir(URL(filePath: dir))
      }

      return RbObject.nilObject
    }
  )

  // Returns true if the file with the specific context was changed, false if not and nil
  // if the file doesn't exist
  try module.defineMethod(
    "fileChangedWithContext",
    argsSpec: RbMethodArgsSpec(
      leadingMandatoryCount: 2
    ),
    body: { obj, method in
      let filename: String = try method.args.mandatory[0].convert()
      let fileContext: String = try method.args.mandatory[1].convert()

      let file = URL(filePath: filename)

      if !FileManager.default.exists(at: file) {
        return RbObject.nilObject
      }

      return RbObject(try context.value.withInner { (context: borrowing Beaver) in
        return try context.fileChanged(file, context: fileContext)
      })
    }
  )

  try module.defineMethod(
    "shAsync",
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
