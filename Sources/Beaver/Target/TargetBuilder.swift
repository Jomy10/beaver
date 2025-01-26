// NOTES:
// We use a TaskGroup to manage the amount of threads for us. TaskGroup will
// never spawn more threads than there are processors to avoid context switching.
// tasks will wait until a thread has finished to start.

import Foundation
import ProgressIndicators
import class ProgressIndicators.ProgressBar
import ColorizeSwift
import Atomics
import Utils

/// This structure holds the dependants of all targets as well as the leaf nodes to start from
/// Basically a reversed tree starting from the leaves
struct DependencyTree {
  let resultTarget: TargetRef
  let resultTargetArtifact: ArtifactType?
  var nodes: [LibraryTargetDependency:NodeData]
  var leaves: [LibraryTargetDependency]

  struct NodeData {
    /// These are all the dependenants of this node
    let dependants: [LibraryTargetDependency]
    /// The amount of buildable dependencies of this node
    let dependencyCount: Int
    var dependenciesBuilt: ManagedAtomic<Int> = ManagedAtomic(0)
    var status: TargetBuilder.BuildStatus = .pending
  }

  private mutating func addNodes(dependencies: [LibraryTargetDependency:[LibraryTargetDependency]], dependants: [LibraryTargetDependency:[LibraryTargetDependency]]) {
    for (target, dependants) in dependants {
      let dependencyCount = dependencies[target]!.count
      self.nodes[target] = NodeData(
        dependants: dependants,
        dependencyCount: dependencyCount
      )
      if dependencyCount == 0 {
        self.leaves.append(target)
      }
    }
  }

  private static func collectDependencies(_ target: LibraryTargetDependency, context: borrowing Beaver) async -> [LibraryTargetDependency] {
    await context.withTarget(target.target) { (target: borrowing AnyTarget) in
      target.dependencies.compactMap { dependency in
        switch (dependency) {
          case .library(let lib): return lib
          default: return nil
        }
      }
    }
  }

  init(target: TargetRef, artifact: ArtifactType?, context: borrowing Beaver) async throws {
    self.resultTarget = target
    self.resultTargetArtifact = artifact
    self.nodes = [:]
    self.leaves = []

    let ctxPtr = withUnsafePointer(to: context) { $0 }
    try await context.withTarget(target) { (target: borrowing AnyTarget) in
      // key --depends on--> val
      var dependencies: [LibraryTargetDependency:[LibraryTargetDependency]] = [:]
      // val <--depends on-- key
      var dependants: [LibraryTargetDependency:[LibraryTargetDependency]] = [:]
      try await target.loopUniqueDependenciesRecursive(context: ctxPtr.pointee) { dependency in
        switch (dependency) {
          case .library(let lib):
            if dependencies[lib] == nil {
              let deps = await Self.collectDependencies(lib, context: ctxPtr.pointee)
              dependencies[lib] = deps

              if dependants[lib] == nil {
                dependants[lib] = []
              }

              for dep in deps {
                if dependants[dep] == nil {
                  dependants[dep] = []
                }
                dependants[dep]!.append(lib)
              }
            }
          default: // these kind dependencies are already built (and have no dependencies)
            break
        }
      }
      self.addNodes(dependencies: dependencies, dependants: dependants)
    }
  }
}

actor TargetBuilder {
  let tree: DependencyTree
  var hasError: ManagedAtomic<Bool>

  init(target: TargetRef, artifact: ArtifactType?, context: borrowing Beaver) async throws {
    self.tree = try await DependencyTree(target: target, artifact: artifact, context: context)
    self.hasError = ManagedAtomic(false)
  }

  enum BuildStatus: Equatable {
    case pending
    case done
    case error(any Error)
    case cancelled

    var formatted: String {
      switch (self) {
        case .pending: "PENDING".bold()
        case .done: "DONE".green()
        case .error(_): "ERROR".red()
        case .cancelled: "CANCELLED".yellow()
      }
    }

    static func ==(lhs: BuildStatus, rhs: BuildStatus) -> Bool {
      switch (lhs) {
        case .pending: rhs == .pending
        case .done: rhs == .done
        case .error(_): if case .error(_) = rhs { true } else { false }
        case .cancelled: rhs == .cancelled
      }
    }
  }

  /// Finish the target and start building its dependants
  func finish(target: LibraryTargetDependency, withStatus status: BuildStatus, message: String, group: inout TaskGroup<Void>, context: UnsafeSendable<UnsafePointer<Beaver>>) {
    switch (status) {
      case .pending:
        fatalError("unreachable")
      case .done:
        for dependant in self.tree.nodes[target]!.dependants {
          if self.tree.nodes[target]!.status != .pending {
            continue
          }

          let builtCount = self.tree.nodes[dependant]!.dependenciesBuilt.wrappingIncrementThenLoad(ordering: .sequentiallyConsistent)
          // Build target if all its dependencies are built
          if self.tree.nodes[dependant]!.dependencyCount == builtCount {
            self.buildTarget(target: dependant, group: &group, context: context)
          }
        }
        //self.buildTarget(target: target, group: &group, context: context)
        MessageHandler.print("[\(status.formatted)] \(message)")
      case .error(let error):
        MessageHandler.print("[\(status.formatted)] \(message): \(error)")
        self.hasError.store(true, ordering: .sequentiallyConsistent)
        for dependant in self.tree.nodes[target]!.dependants {
          self.finish(target: dependant, withStatus: .cancelled, message: message, group: &group, context: context)
        }
      case .cancelled:
        MessageHandler.print("[\(status.formatted)] \(message)")
        for dependant in self.tree.nodes[target]!.dependants {
          self.finish(target: dependant, withStatus: .cancelled, message: message, group: &group, context: context)
        }
    }
  }

  /// Build a target, starting its dependants if all of its dependencies have been built
  func buildTarget(target: LibraryTargetDependency, group: inout TaskGroup<Void>, context: UnsafeSendable<UnsafePointer<Beaver>>) {
    let groupPtr = UnsafeSendable(withUnsafeMutablePointer(to: &group) { $0 })
    group.addTask {
      var spinner: ProgressBar? = nil
      var message: String? = nil
      var status: BuildStatus? = nil
      do {
        try await context.value.pointee.withProjectAndLibrary(target.target) { (project: borrowing AnyProject, library: borrowing AnyLibrary) in
          let name = if project.id == context.value.pointee.currentProjectIndex {
            library.name
          } else {
            "\(project.name):\(library.name)"
          }
          message = "Building \(name) (\(target.artifact))"
          spinner = MessageHandler.newSpinner(message!)
          try await library.build(artifact: target.artifact, projectBaseDir: project.baseDir, projectBuildDir: project.buildDir, context: context.value.pointee)
        }
        status = .done
      } catch let error {
        status = .error(error)
      }
      await spinner?.finish()
      await self.finish(target: target, withStatus: status!, message: message!, group: &groupPtr.value.pointee, context: context)
    }
  }

  func buildLast(context: UnsafeSendable<UnsafePointer<Beaver>>) async {
    let resultTargetArtifact = self.tree.resultTargetArtifact
    let resultTarget = self.tree.resultTarget
    let hasError = self.hasError.load(ordering: .sequentiallyConsistent)

    var spinner: ProgressBar? = nil
    var message: String? = nil
    var status: BuildStatus? = nil
    var postfix: String? = nil

    do {
      try await context.value.pointee.withProjectAndTarget(resultTarget) { (project: borrowing AnyProject, target: borrowing AnyTarget) in
        message = "Building \(target.name)"
        if hasError {
          status = .cancelled
          return
        }
        spinner = MessageHandler.newSpinner(message!)
        if let artifact = resultTargetArtifact {
          try await target.build(artifact: artifact, projectBaseDir: project.baseDir, projectBuildDir: project.buildDir, context: context.value.pointee)
        } else {
          try await target.build(projectBaseDir: project.baseDir, projectBuildDir: project.buildDir, context: context.value.pointee)
        }
        status = .done
      }
    } catch let error {
      status = .error(error)
      postfix = ": \(error)"
    }
    await spinner?.finish()
    MessageHandler.print("[\(status!.formatted)] \(message!)\(postfix ?? "")")
  }

  func build(context: borrowing Beaver) async {
    MessageHandler.enableIndicators()
    defer { MessageHandler.closeIndicators() }
    let contextPtr = UnsafeSendable(withUnsafePointer(to: context) { $0 })
    await withTaskGroup(of: Void.self) { group in
      for target in self.tree.leaves {
        self.buildTarget(target: target, group: &group, context: contextPtr)
      }
    }
    await self.buildLast(context: contextPtr)
  }
}

protocol AsyncCustomDebugStringConvertible {
  var debugDescription: String { get async }
}

extension TargetBuilder: AsyncCustomDebugStringConvertible {
  var debugDescription: String {
    get async {
      """
      TargetBuilder(
        tree: \(await self.tree.debugDescription.replacing("\n", with: "\n        ")),
        hasError: \(self.hasError)
      )
      """
    }
  }
}

extension DependencyTree: AsyncCustomDebugStringConvertible {
  var debugDescription: String {
    get async {
      """
      DependencyTree(
        resultTarget: \(self.resultTarget),
        resultTargetArtifact: \(String(describing: self.resultTargetArtifact)),
        nodes: \(self.nodes),
        leavers: \(self.leaves)
      )
      """
    }
  }
}
