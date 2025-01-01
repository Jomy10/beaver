import Foundation
import Tree
import Collections
import Atomics
import Semaphore
import TaskProgress

extension Tree.Node: @retroactive CustomStringConvertible {
  public var description: String {
    if self.isLeaf {
      "Node(\(self.element))"
    } else {
      "Node(\(self.element), children: \(self.children))"
    }
  }
}

//extension Tree.Node: @retroactive CustomStringConvertible {
//  public var description: String {
//    var string = "\(self.element)\n"
//    for node in self.children {
//      string += node.description.split(separator: "\n").map { "  \($0)\n" }.joined()
//    }
//    return string
//  }
//}

extension Tree.Node {
  func treeLeaves() -> [Tree.Node<Element>] {
    return self.breadthFirst.filter { node in node.isLeaf }
  }
}

struct TargetRef: Identifiable, Hashable, Equatable, Sendable {
  let name: String
  let project: ProjectRef

  var id: Self {
    self
  }

  init(_ libRef: borrowing LibraryRef) {
    self.name = libRef.name
    self.project = libRef.project
  }

  init(name: String, project: ProjectRef) {
    self.name = name
    self.project = project
  }
}

struct DependencyGraph: ~Copyable, @unchecked Sendable {
  let root: Node<TargetRef>

  private static func constructTree(forTarget target: String, inProject project: ProjectRef, context: borrowing Beaver) async throws -> Node<TargetRef> {
    let root = UnsafeSendable(Node(TargetRef(name: target, project: project)))

    try await context.withProject(index: project) { (project: borrowing Project) async throws -> Void in
      try await project.withTarget(named: target) { (target: borrowing any Target) async throws -> Void in
        for dependency in target.dependencies {
          let node = try await constructTree(forTarget: dependency.name, inProject: dependency.project, context: context)
          root.value.append(child: node)
        }
      }
    }

    return root.value
  }

  init(startingFromTarget target: String, inProject project: ProjectRef, context: borrowing Beaver) async throws {
    self.root = try await Self.constructTree(forTarget: target, inProject: project, context: context)
  }
}

actor DependencyBuilder {
  //let graph: DependencyGraph
  let availableProcessCount: Int
  var dependencies: [Dependency]
  let doneSignal = AsyncSemaphore(value: 0)
  // TODO: Mutex instead of RWLock
  let processResult: AsyncRWLock<Deque<Result<(target: TargetRef, status: DependencyStatus), BuildError>>>

  struct Dependency: @unchecked Sendable {
    let node: Node<TargetRef>
    var status: DependencyStatus
  }

  enum DependencyStatus {
    case done
    case started
    case waiting
    case error
    case cancelled
  }

  struct BuildError: Error {
    let target: TargetRef
    let error: any Error
  }

  public init(_ graph: borrowing DependencyGraph, maxProcessCount: Int = ProcessInfo.processInfo.activeProcessorCount) {
    self.dependencies = graph.root.breadthFirst.reversed().uniqueKeepingOrder.map { node in
      Dependency(node: node, status: .waiting)
    }
    self.processResult = AsyncRWLock(Deque())
    self.availableProcessCount = maxProcessCount
  }

  func isDone(_ node: Node<TargetRef>) -> Bool {
    return self.dependencies.contains { dep in
      dep.node == node && dep.status == .done
    }
  }

  func isError(_ node: Node<TargetRef>) -> Bool {
    return self.dependencies.contains { dep in
      dep.node == node && dep.status == .error
    }
  }

  func isErrorOrCancelled(_ node: Node<TargetRef>) -> Bool {
    return self.dependencies.contains { dep in
      dep.node == node && (dep.status == .error || dep.status == .cancelled)
    }
  }

  func shouldBuild(_ node: Node<TargetRef>) -> Bool {
    return self.dependencies.contains { dep in
      dep.node == node && dep.status != .done && dep.status != .error && dep.status != .cancelled
    }
  }

  func areAllDone() -> Bool {
    return self.dependencies.first(where: { dep in dep.status != .done }) == nil
  }

  func areAllBuilt() -> Bool {
    return !self.dependencies.contains(where: { dep in
      dep.status == .waiting || dep.status == .started
    })
  }

  public func run(context: borrowing Beaver) async throws {
    let ctxPtr = UnsafeSendable(withUnsafePointer(to: context) { $0 }) // we assure that the pointer won't be used after this function returns
    var runningProcesses = 0
    while true {
      /// Start as much dependencies as possible concurrently
      for (i, dependency) in self.dependencies.enumerated() {
        if runningProcesses == self.availableProcessCount { break } // maxProcesses reached, stop starting new ones
        if dependency.status == .done || dependency.status == .cancelled || dependency.status == .error { continue }
        /// If this node has no dependencies, or if all if its dependencies are built, then we can built this one
        if dependency.node.children.count == 0 || dependency.node.children.first(where: { !self.isDone($0) }) == nil {
          runningProcesses += 1
          self.dependencies[i].status = .started
          self.build(target: dependency.node.element, context: ctxPtr)
        }
        // Cancel building the target
        if dependency.node.children.first(where: { self.isErrorOrCancelled($0) }) != nil {
          await self.processResult.write { queue in
            queue.append(.success((target: dependency.node.element, status: .cancelled)))
          }
          let projectName: String? = if dependency.node.element.project == context.currentProjectIndex {
            nil
          } else {
            try await context.withProject(index: dependency.node.element.project) { (project: borrowing Project) in
              project.name
            }
          }
          let desc: String
          if let projectName = projectName {
            desc = "\(projectName):\(dependency.node.element.name)"
          } else {
            desc = dependency.node.element.name
          }
          let task = ProgressBarTask("Building \(desc)")
          await MessageHandler.addTask(task, targetRef: dependency.node.element)
          task.cancel()
          self.doneSignal.signal()
        }
      }

      // Wait for a process to exit
      // TODO: drain queue instead?
      await self.doneSignal.wait()
      runningProcesses -= 1
      let result = await self.processResult.write({ queue in
        queue.popFirst()
      })!
      switch (result) {
        case .failure(let error):
          let index = self.dependencies.firstIndex(where: { dep in dep.node.element == error.target })!
          self.dependencies[index].status = .error
          try await MessageHandler.print("ERROR: \(error)", targetRef: error.target)
          await MessageHandler.print("ERROR building \(error.target.name): \(error.error)")
        case .success(let result):
          let index = self.dependencies.firstIndex(where: { dep in dep.node.element == result.target })!
          self.dependencies[index].status = result.status
      }
      if self.areAllBuilt() {
        break
      }
    }
  }

  func build(target: TargetRef, context: UnsafeSendable<UnsafePointer<Beaver>>) {
    //let ctxPtr = withUnsafePointer(to: context) { $0 } // we assure that the context is borrowed for the whole duration of the task in `run`
    Task.detached(priority: .high) {
      let task: UnsafeSharedBox<ProgressTask?> = UnsafeSharedBox(nil)
      do {
        try await context.value.pointee.withProject(index: target.project) { (project: borrowing Project) in
          task.value = SpinnerProgressTask("Building \(context.value.pointee.currentProjectIndex == target.project ? "" : project.name + ":")\(target.name)")
          await MessageHandler.addTask(task.value!, targetRef: target)
          try await project.withTarget(named: target.name) { (target: borrowing any Target) in
            try await target.build(baseDir: project.baseDir, buildDir: project.buildDir, context: context.value.pointee)
          }
        }

        await self.processResult.write { queue in
          queue.append(.success((target: target, status: .done)))
        }
        task.value!.finish()
      } catch let error {
        await self.processResult.write { queue in
          queue.append(.failure(BuildError(target: target, error: error)))
        }
        task.value?.setError()
      }
      self.doneSignal.signal()
    }
  }
}

//struct DependencyBuilder: ~Copyable {
//  let graph: DependencyGraph
//  let processCount: Int = ProcessInfo.processInfo.activeProcessorCount
//  /// Amount of tasks currently working
//  let workingTasks = ManagedAtomic(0)
//  /// The dependencies that have started building
//  let dependenciesStarted: AsyncRWLock<Set<TargetRef>> = AsyncRWLock(Set())
//  let dependenciesFinished: AsyncRWLock<Set<TargetRef>> = AsynRWLock(Set())
//  let queuedTasks: AsyncRWLock<Deque<() -> Void>> = AsyncRWLock(Deque())

//  // spawn x threads -> let them all check for jobs to be done

//  init(_ graph: consuming DependencyGraph) {
//    self.graph = graph
//  }

//  func registerTask(node: Node<TargetRef>, context: borrowing Beaver) async throws {
//    await self.queuedTasks.write { queue in
//      queue.append({
//        Task.detached(priority: .high) {
//          try await self.buildNode(node: node, context: context)
//        }
//      })
//    }
//  }

//  func buildNode(node: Node<TargetRef>, context: borrowing Beaver) async throws {
//    let dependency = node.element
//    defer { self.workingTasks.wrappingDecrement(ordering: .releasing) }

//    // Check that all of this node's dependencies are built
//    let allChildrenBuilt = self.dependenciesStarted.read { started in
//      for child in node.children {
//        if !started.contains(child) {
//          return false
//        }
//      }
//      return true
//    }
//    if !allChildrenBuilt {
//      self.registerTask(node: node, context: context)
//    }

//    // Check that if this node has already been built, else built its dependent
//    let nodeHasStarted = self.dependenciesStarted.write { started in
//      if started.contains(dependency) {
//        return true
//      } else {
//        started.insert(dependency)
//        return false
//      }
//    }
//    if nodeHasStarted {
//      print("\(dependency) already built")
//      // Build dependent
//      guard let parent = node.parent?.element else { return }
//      await self.registerTask(node: parent, context: context)
//      return
//    }

//    print("building \(dependency)")

//    // Build this node
//    try await context.withProject(index: dependency.project) { (project: borrowing Project) in
//      try await project.withTarget(named: dependency.name) { (target: borrowing any Target) in
//        try await target.build(baseDir: project.baseDir, buildDir: project.buildDir, context: context)
//      }
//    }

//    await self.dependenciesFinished.write { finished in
//      finished.insert(node.element)
//    }

//    print("built \(dependency)")

//    // Build dependent
//    guard let parent = node.parent?.element else { return }
//    await self.registerTask(node: parent, context: context)
//  }

//  /// Build the whole dependency graph
//  func build(context: borrowing Beaver) async {
//    let leaves = self.graph.root.treeLeaves()

//    await self.queuedTasks.write { queue in
//      for leaf in self.graph.root.treeLeaves() {
//        queue.append({
//          Task.detached(priority: .high) {
//            try await self.buildNode(node: leaf, context: context)
//          }
//        })
//      }
//    }

//    while true {
//      if self.workingTasks.load(ordering: .relaxed) < self.processCount {
//        guard let startTask = self.queuedTasks.write { queue in
//          queue.popFirst()
//        } else {
//          if self.amountFinished.load(ordering: .relaxed) == self.dependenciesToFinish {
//            break
//          }
//          await Task.yield()
//          continue
//        }
//        self.workingTasks.wrappingIncrement(ordering: .acquiring)
//        startTask()
//      } else {
//        await Task.yield()
//      }
//    }
//  }
//}
