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

//public struct TargetRef: Identifiable, Hashable, Equatable, Sendable {
//  public let name: String
//  public let project: ProjectRef

//  public var id: Self {
//    self
//  }

//  public init(_ libRef: borrowing LibraryRef) {
//    self.name = libRef.name
//    self.project = libRef.project
//  }

//  public init(name: String, project: ProjectRef) {
//    self.name = name
//    self.project = project
//  }
//}

/// A Tree structure showing the dependency graph
///
/// e.g.
/// ```
/// A - B - D
///   \ C - B - D
///       \ D
/// ```
struct DependencyGraph: ~Copyable, @unchecked Sendable {
  fileprivate let root: Node<DependencyRef>

  enum CreationError: Error {
    case noTarget(named: String)
  }

  private static func constructTree(forTarget target: TargetRef, artifact: ArtifactType? = nil, context: borrowing Beaver) async throws -> Node<DependencyRef> {
    //let target = TargetRef(name: targetIndex, project: project)
    let root = Node(DependencyRef(target: target, artifact: artifact))

    try await context.withTarget(target) { (target: borrowing any Target) async throws -> Void in
      for dependency in target.dependencies {
        let node = try await Self.constructTree(forTarget: dependency.library, artifact: dependency.artifact.asArtifactType(), context: context)
        root.append(child: node)
      }
    }
    //try await context.withProject(project) { (project: borrowing Project) async throws -> Void in
    //  try await project.withTarget(targetIndex) { (target: borrowing any Target) async throws -> Void in
    //    for dependency in target.dependencies {
    //      let node = try await constructTree(forTarget: dependency.library, inProject: dependency.library.project, context: context)
    //      root.value.append(child: node)
    //    }
    //  }
    //}

    return root
  }

  init(startingFromTarget target: String, inProject project: ProjectRef, artifact: ArtifactType? = nil, context: borrowing Beaver) async throws {
    guard let targetIndex = await context.withProject(project, { (project: borrowing Project) in
      return await project.targetIndex(name: target)
    }) else {
      throw CreationError.noTarget(named: target)
    }
    try await self.init(startingFrom: TargetRef(target: targetIndex, project: project), artifact: artifact, context: context)
    //self.root = try await Self.constructTree(forTarget: TargetRef(target: targetIndex, project: project), context: context)
  }

  init(startingFrom target: TargetRef, artifact: ArtifactType? = nil, context: borrowing Beaver) async throws {
    await MessageHandler.trace("Resolving dependencies...")
    self.root = try await Self.constructTree(forTarget: target, artifact: artifact, context: context)
  }
}

fileprivate struct DependencyRef: Identifiable, Sendable, Equatable, Hashable {
  let target: TargetRef
  let artifact: ArtifactType?

  var id: Self {
    self
  }
}

// TODO: check circular references!!
// in the current implementation this will cause an infinite loop

// TODO: Change Node's type to (TargetRef, ArtifactType) --> Only build necessary artifacts ??

/// Uses a dependency graph to determine how to build dependencies
///
/// Take the DependencyGraph example.
/// This gets converterd to: D - B - C - A
/// - D will get built, none of the proceeding can be built.
/// - When D is finished, B will get built, C has to wait on B and A has to wait on both B and C to build
/// - When B is finished, C will get built and A will be waiting
/// - When A is finished, then A will get built
///
/// All dependencies in the array are checked whenever a target is built. When that is done, it will wait
/// until a signal is received from one of the finished building targets and check dependencies again
actor DependencyBuilder {
  fileprivate var dependencies: [Dependency]
  fileprivate let doneSignal = AsyncSemaphore(value: 0)
  // TODO: Mutex instead of RWLock
  fileprivate let processResult: AsyncRWLock<Deque<(dependency: DependencyRef, result: Result<DependencyStatus, any Error>)>>

  // TODO: rename to BuildDependency
  fileprivate struct Dependency: @unchecked Sendable {
    let node: Node<DependencyRef>
    var status: DependencyStatus
  }

  enum DependencyStatus: Sendable {
    case done
    /// The dependency is currently building
    case started
    case waiting
    case error
    case cancelled
  }

  @available(*, deprecated)
  struct BuildError: Error {
    let target: TargetRef
    let error: any Error
  }

  public init(_ graph: borrowing DependencyGraph, context: borrowing Beaver) async throws {
    self.dependencies = await graph.root.breadthFirst.reversed().uniqueKeepingOrder
      .asyncFilter { node in
        await context.isBuildable(target: node.element.target)
      }
      .map { node in
        Dependency(node: node, status: .waiting)
      }
    self.processResult = AsyncRWLock(Deque())
    //self.availableProcessCount = maxProcessCount
  }

  fileprivate func isDone(_ node: Node<DependencyRef>) -> Bool {
    return self.dependencies.contains { dep in
      dep.node == node && dep.status == .done
    }
  }

  fileprivate func isError(_ node: Node<DependencyRef>) -> Bool {
    return self.dependencies.contains { dep in
      dep.node == node && dep.status == .error
    }
  }

  fileprivate func isErrorOrCancelled(_ node: Node<DependencyRef>) -> Bool {
    return self.dependencies.contains { dep in
      dep.node == node && (dep.status == .error || dep.status == .cancelled)
    }
  }

  fileprivate func shouldBuild(_ node: Node<DependencyRef>) -> Bool {
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
    await MessageHandler.trace("Building targets...")

    let ctxPtr = UnsafeSendable(withUnsafePointer(to: context) { $0 }) // we assure that the pointer won't be used after this function returns
    while true {
      /// Start as much dependencies as possible concurrently
      for (i, dependency) in self.dependencies.enumerated() {
        if !(GlobalThreadCounter.canStartNewProcess()) { break }

        if dependency.status == .done || dependency.status == .cancelled || dependency.status == .error || dependency.status == .started { continue }

        /// If this node has no dependencies, or if all if its dependencies are built, then we can built this one
        if dependency.node.children.count == 0 || dependency.node.children.first(where: { !self.isDone($0) }) == nil {
          //var priority: TaskPriority = .high
          //if target.value.pointee.spawnsMoreThreadsWithGlobalThreadManager {
          //  priority = .medium
          //} else {
          //  await GlobalThreadCounter.newProcess()
          //}
          self.dependencies[i].status = .started
          self.build(dependency: dependency.node.element, context: ctxPtr)

          // Cancel building the target
        } else if dependency.node.children.first(where: { self.isErrorOrCancelled($0) }) != nil {
          await self.processResult.write { queue in
            queue.append((dependency: dependency.node.element, result: .success(.cancelled)))
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
      switch (result.result) {
        case .failure(let error):
          // Finish
          let index = self.dependencies.firstIndex(where: { dep in dep.node.element == result.dependency })!
          self.dependencies[index].status = .error

          // Message
          let targetDesc = await result.dependency.target.description(context: context)!
          let spinner = await MessageHandler.getSpinner(targetRef: result.dependency.target)
          //await spinner.finish(message: "Building \(targetDesc): \("ERROR".red())")
          await spinner?.finish()
          await MessageHandler.print("[\(DependencyStatus.error)] Building \(targetDesc)\n\(String(describing: error))")
        case .success(let newStatus):
          // Finish
          let index = self.dependencies.firstIndex(where: { dep in dep.node.element == result.dependency })!
          self.dependencies[index].status = newStatus

          // Message
          let targetDesc = await result.dependency.target.description(context: context)!
          let spinner = await MessageHandler.getSpinner(targetRef: result.dependency.target)
          //await spinner?.finish(message: "Building \(targetDesc) \(statusString)")
          await spinner?.finish()
          await MessageHandler.print("[\(newStatus)] Building \(targetDesc)") // TODO: get message from spinner if possible?
      }
      if self.areAllBuilt() {
        break
      }
    }
  }

  fileprivate func build(
    dependency: DependencyRef,
    //target: TargetRef,
    //artifact: ArtifactType?,
    //target: UnsafeSendable<UnsafePointer<any Target>>,
    //projectIndex: ProjectRef,
    //project: UnsafeSendable<UnsafePointer<Project>>,
    context: UnsafeSendable<UnsafePointer<Beaver>>,
    priority: TaskPriority = .high
  ) {
    Task.detached(priority: priority) {
      let result: Result<DependencyStatus, any Error> = await Result { try await context.value.pointee.withProjectAndTarget(dependency.target) { (project, target) in
        await MessageHandler.addTask(
          "Building \(context.value.pointee.currentProjectIndex == dependency.target.project ? "" : project.name + ":")\(target.name)",
          targetRef: dependency.target
        )
        switch (dependency.artifact) {
          case .library(let artifactType):
            //(target as! any Library)._build(artifact: artifactType, baseDir: project.baseDir, buildDir: project.buildDir, context: context.value.pointee)
            //try await build(target as! any Library, artifact: artifactType, baseDir: project.baseDir, buildDir: project.buildDir, context: context.value.pointee)
            try await (target as! any Library).build(artifact: artifactType, baseDir: project.baseDir, buildDir: project.buildDir, context: context.value.pointee)
          case .executable(let artifactType):
            try await (target as! any Executable).build(artifact: artifactType, baseDir: project.baseDir, buildDir: project.buildDir, context: context.value.pointee)
          case nil:
            try await target.build(baseDir: project.baseDir, buildDir: project.buildDir, context: context.value.pointee)
        }

        if !target.spawnsMoreThreadsWithGlobalThreadManager {
          GlobalThreadCounter.releaseProcess()
        }

        return .done
      }}

      await self.processResult.write { queue in
        queue.append((dependency: dependency, result: result))
      }
      self.doneSignal.signal()
      //let targetRef = TargetRef(name: target.value.pointee.name, project: projectIndex)
      //do {
      //  try await target.value.pointee.build(baseDir: project.value.pointee.baseDir, buildDir: project.value.pointee.buildDir, context: context.value.pointee)

      //  await self.processResult.write { queue in
      //    queue.append(.success((target: targetRef, status: .done)))
      //  }
      //} catch let error {
      //  await self.processResult.write { queue in
      //    queue.append(.failure(BuildError(target: targetRef, error: error)))
      //  }
      //}
      //self.doneSignal.signal()
      //if !target.value.pointee.spawnsMoreThreadsWithGlobalThreadManager {
      //  GlobalThreadCounter.releaseProcess()
      //}
    }
  }
}

extension DependencyBuilder.DependencyStatus: CustomStringConvertible {
  public var description: String {
    switch (self) {
      case .done: "DONE".green()
      case .started: "STARTED".blue()
      case .waiting: "WAITING".blue()
      case .error: "ERR".red()
      case .cancelled: "CANCELLED".yellow()
    }
  }
}

extension Library {
  func _build(artifact: LibraryArtifactType, baseDir: borrowing URL, buildDir: borrowing URL, context: borrowing Beaver) async throws where ArtifactType == LibraryArtifactType {
    try await self.build(artifact: artifact, baseDir: baseDir, buildDir: buildDir, context: context)
  }
}

//func build<TargetType: Target>(_ target: any TargetType, artifact: TargetType.ArtifactType, baseDir: borrowing URL, buildDir: borrowing URL, context: borrowing Beaver) async throws {
//  try await target.build(artifact: artifact, buildDir: buildDir, baseDir: baseDir, context: context)
//}
