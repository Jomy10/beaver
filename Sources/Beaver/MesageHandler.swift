import TaskProgress

struct MessageHandler {
  private static let data: AsyncRWLock<Self.Data> = AsyncRWLock(.init())

  struct Data {
    var tasks: [ObjectIdentifier:ProgressTask] = [:]
    var targetToId: [TargetRef:ObjectIdentifier] = [:]
    var indicatorsEnabled: Bool = false
  }

  struct NoTaskError: Error, @unchecked Sendable {
    let id: Any
  }

  public static func enableIndicators() async {
    ProgressIndicators.global.show()
    await self.data.write { data in data.indicatorsEnabled = true }
  }

  public static func closeIndicators() async {
    await self.data.write { data in data.indicatorsEnabled = false }
    ProgressIndicators.global.setCanClose()
  }

  public static func addTask(_ task: ProgressTask, targetRef: TargetRef? = nil) async {
    ProgressIndicators.global.addTask(task)
    await self.data.write { data in
      data.tasks[task.id] = task
      if let targetRef = targetRef {
        data.targetToId[targetRef] = task.id
      }
    }
  }

  public static func print(_ message: String, task: ProgressTask) async {
    if await self.data.read({ data in data.indicatorsEnabled }) {
      task.setMessage(message)
    } else {
      Swift.print(message)
    }
  }

  public static func print(_ message: String, id: ObjectIdentifier) async throws(NoTaskError) {
    guard let task = await self.data.read({ $0.tasks[id] }) else {
      throw NoTaskError(id: id)
    }
    await self.print(message, task: task)
  }

  public static func print(_ message: String, targetRef: TargetRef) async throws(NoTaskError) {
    guard let id = await self.data.read({ $0.targetToId[targetRef] }) else {
      throw NoTaskError(id: targetRef)
    }
    try await self.print(message, id: id)
  }

  public static func print(_ message: String) async {
    if await self.data.read({ data in data.indicatorsEnabled }) {
      ProgressIndicators.global.globalMessage(message)
    } else {
      Swift.print(message)
    }
  }

  public static func print(_ message: String, to stream: IOStream) async {
    if await self.data.read({ data in data.indicatorsEnabled }) {
      // TODO
      ProgressIndicators.global.globalMessage(message)
    } else {
      IO.print(message, to: stream)
    }
  }
}
