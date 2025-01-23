import Foundation
import RubyGateway
import Beaver
import Utils

func loadFileMethods(in module: RbObject, queue: SyncTaskQueue, context: UnsafeSendable<Rc<Beaver>>) throws {
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
}
