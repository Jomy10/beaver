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
    "sh",
    argsSpec: RbMethodArgsSpec(
      supportsSplat: true
    ),
    body: { obj, method in
      let cmd: [String] = try method.args.splatted.map { try $0.convert(to: String.self) }

      if cmd.count == 0 {
        throw ShError("no arguments")
      } else if cmd.count == 1 {
        try Tools.exec(Tools.sh!, ["-c", cmd.first!])
      } else {
        let cmdName = Tools.which(cmd[cmd.startIndex])! // TODO: erro
        let arguments = cmd[cmd.index(after: cmd.startIndex)...]
        try Tools.exec(cmdName, Array(arguments))
      }

      return RbObject.nilObject
    }
  )
}
