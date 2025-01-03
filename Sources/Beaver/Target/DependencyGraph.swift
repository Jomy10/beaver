import Foundation
@preconcurrency import Tree
import Collections
import Atomics
import Semaphore
import ProgressIndicators
//import TaskProgress

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

public struct TargetRef: Identifiable, Hashable, Equatable, Sendable {
  public let name: String
  public let project: ProjectRef

  public var id: Self {
    self
  }

  public init(_ libRef: borrowing LibraryRef) {
    self.name = libRef.name
    self.project = libRef.project
  }

  public init(name: String, project: ProjectRef) {
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

  public init(_ graph: borrowing DependencyGraph, context: borrowing Beaver) async throws {
    self.dependencies = try await graph.root.breadthFirst.reversed().uniqueKeepingOrder
      .asyncFilter { node in
        try await context.isBuildable(target: node.element)
      }
      .map { node in
        Dependency(node: node, status: .waiting)
      }
    self.processResult = AsyncRWLock(Deque())
    //self.availableProcessCount = maxProcessCount
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
    while true {
      /// Start as much dependencies as possible concurrently
      for (i, dependency) in self.dependencies.enumerated() {
        if !(GlobalThreadCounter.canStartNewProcess()) { break }

        if dependency.status == .done || dependency.status == .cancelled || dependency.status == .error { continue }

        /// If this node has no dependencies, or if all if its dependencies are built, then we can built this one
        if dependency.node.children.count == 0 || dependency.node.children.first(where: { !self.isDone($0) }) == nil {
          let (target, project) = try await context.withProject(index: dependency.node.element.project) { (project: borrowing Project) in
            (
              UnsafeSendable(try await project.withTarget(named: dependency.node.element.name) { (target: borrowing any Target) in
                return withUnsafePointer(to: target) { $0 }
              }),
              UnsafeSendable(withUnsafePointer(to: project) { $0 })
            )
          }
          var priority: TaskPriority = .high
          if target.value.pointee.spawnsMoreThreadsWithGlobalThreadManager {
            priority = .medium
          } else {
            await GlobalThreadCounter.newProcess()
          }
          self.dependencies[i].status = .started
          self.build(target: target, projectIndex: dependency.node.element.project, project: project, context: ctxPtr, priority: priority)

          // Cancel building the target
        } else if dependency.node.children.first(where: { self.isErrorOrCancelled($0) }) != nil {
          await self.processResult.write { queue in
            queue.append(.success((target: dependency.node.element, status: .cancelled)))
          }
          self.doneSignal.signal()
        }
      }

      // Wait for a process to exit
      // TODO: drain queue instead?
      await self.doneSignal.wait()
      let result = await self.processResult.write({ queue in
        queue.popFirst()
      })!
      switch (result) {
        case .failure(let error):
          let index = self.dependencies.firstIndex(where: { dep in dep.node.element == error.target })!
          self.dependencies[index].status = .error
          let targetDesc = if context.currentProjectIndex == error.target.project {
            error.target.name
          } else {
            try await context.withProject(index: error.target.project) { $0.name } + ":" + error.target.name
          }
          await MessageHandler.print("[\("ERROR".red())] Building \(targetDesc)\n\(String(describing: error.error))")
          let spinner = await MessageHandler.getSpinner(targetRef: error.target)!
          await spinner.finish(message: "Building \(targetDesc): \("ERROR".red())")
        case .success(let result):
          let index = self.dependencies.firstIndex(where: { dep in dep.node.element == result.target })!
          self.dependencies[index].status = result.status

          let targetDesc = if context.currentProjectIndex == result.target.project {
            result.target.name
          } else {
            try await context.withProject(index: result.target.project) { $0.name } + ":" + result.target.name
          }
          let statusString = switch (result.status) {
            case .cancelled: "CANCELLED".yellow()
            case .done: "DONE".green()
            default: fatalError("Beaver bug: \(result.status) is not a valid successful finish status")
          }
          await MessageHandler.print("[\(statusString)] Building \(targetDesc)")
          let spinner = await MessageHandler.getSpinner(targetRef: result.target)
          await spinner?.finish(message: "Building \(targetDesc) \(statusString)")
      }
      if self.areAllBuilt() {
        break
      }
    }
  }

  func build(
    target: UnsafeSendable<UnsafePointer<any Target>>,
    projectIndex: ProjectRef,
    project: UnsafeSendable<UnsafePointer<Project>>,
    context: UnsafeSendable<UnsafePointer<Beaver>>,
    priority: TaskPriority = .high
  ) {
    Task.detached(priority: priority) {
      let targetRef = TargetRef(name: target.value.pointee.name, project: projectIndex)
      do {
        await MessageHandler.addTask(
          "Building \(context.value.pointee.currentProjectIndex == projectIndex ? "" : project.value.pointee.name + ":")\(target.value.pointee.name)",
          targetRef: targetRef
        )
        try await target.value.pointee.build(baseDir: project.value.pointee.baseDir, buildDir: project.value.pointee.buildDir, context: context.value.pointee)

        await self.processResult.write { queue in
          queue.append(.success((target: targetRef, status: .done)))
        }
      } catch let error {
        await self.processResult.write { queue in
          queue.append(.failure(BuildError(target: targetRef, error: error)))
        }
      }
      self.doneSignal.signal()
      if !target.value.pointee.spawnsMoreThreadsWithGlobalThreadManager {
        GlobalThreadCounter.releaseProcess()
      }
    }
  }
}
