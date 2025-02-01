@preconcurrency import SQLite
import Utils

extension FileCache {
  /// Check if targets are still the same as previous build (i.e. did the script change?)
  /// If the target changed, then its caches are reset
  func checkTargets(context: borrowing Beaver) async throws {
    let tempTargets = TempTargetTable()
    try tempTargets.create(self.db)

    let targets = await context.loopProjectsAndTargets { (project: borrowing AnyProject, target: borrowing AnyTarget) in
      return (projectId: project.id, projectName: project.name, targetId: target.id, targetName: target.name)
    }
    try tempTargets.insert(targets, self.db)

    let targetQuery = tempTargets.table
      .select(
        self.targets.id.qualified,
        self.targets.target.qualified,
        self.targets.project.qualified,
        tempTargets.project.qualified,
        tempTargets.projectName.qualified,
        tempTargets.target.qualified,
        tempTargets.targetName.qualified
      )
      .join(.leftOuter, self.targetCaches.table, on:
           self.targetCaches.project.qualified == tempTargets.projectName.qualified
        && self.targetCaches.target.qualified == tempTargets.targetName.qualified)
      .join(.leftOuter, self.targets.table, on: self.targets.id.qualified == self.targetCaches.targetId.qualified)

    var visitedTargets: [Int64] = []
    for targetRow in try self.db.prepare(targetQuery) {
      MessageHandler.debug("targetRow: \(targetRow)")
      let targetId = targetRow[tempTargets.target.qualified]
      let targets_targetId = targetRow[self.targets.table[SQLite.Expression<Int?>("target")]]
      //let targetName = targetRow[SQLite.Expression<String>("targetName")]
      let projectId = targetRow[tempTargets.project.qualified]
      let targets_projectId = targetRow[self.targets.table[SQLite.Expression<Int?>("project")]]
      //let projectName = targetRow[SQLite.Expression<String>("projectName")]
      let targetRef = TargetRef(target: targetId, project: projectId)
      try await context.withProjectAndTarget(targetRef) { (project: borrowing AnyProject, target: borrowing AnyTarget) in
        if let targetTableId = targetRow[SQLite.Expression<Int64?>("id")] {
          visitedTargets.append(targetTableId)
          // check targetId has changed
          if targetId != targets_targetId {
            try self.db.run(self.targets.table
              .where(self.targets.id.qualified == targetTableId)
              .update([self.targets.target.qualified <- targetId]))
          }
          // check projectId has changed //
          if projectId != targets_projectId {
            try self.db.run(self.targets.table
              .where(self.targets.id.qualified == targetTableId)
              .update([self.targets.project.qualified <- projectId]))
          }

          let cachedDepCount = try self.db.scalar(self.targetDependencyCaches.table
            .where(self.targetDependencyCaches.targetId.qualified == targetTableId)
            .count)
          if cachedDepCount != target.dependencies.count {
            try self.updateDependencies(targetId: targetTableId, target: target)
          } else if target.dependencies.count != 0 {
            let tempDep = TempTargetDependencyTable()
            try tempDep.create(self.db)
            try tempDep.insert(target.dependencies, self.db)

            // Check dependencies have changed //
            let matchingCachedDepCount = try self.db.scalar(
              tempDep.table
                .join(.inner, self.targetDependencyCaches.table,
                  on: self.targetDependencyCaches.targetId.qualified == targetTableId
                  && self.targetDependencyCaches.dependencyType.qualified == tempDep.dependencyType.qualified
                  && (
                        self.targetDependencyCaches.stringData.qualified == tempDep.stringData.qualified
                    || (self.targetDependencyCaches.stringData.qualified === nil && tempDep.stringData.qualified === nil)
                  )
                )
                .join(.leftOuter, self.targets.table, on: self.targetDependencyCaches.dependencyTargetId.qualified == self.targets.id.qualified)
                .where(
                      (self.targets.id.qualifiedOptional === nil && self.targetDependencyCaches.dependencyTargetId.qualified === nil)
                  || (
                        self.targets.id.qualified == self.targetDependencyCaches.dependencyTargetId.qualified
                    && self.targets.target.qualifiedOptional == tempDep.dependencyTarget.qualified
                    && self.targets.project.qualifiedOptional == tempDep.dependencyProject.qualified
                  )
                ).count
            )
            print("[\(targetTableId)] matching count = \(matchingCachedDepCount), totalCount = \(target.dependencies.count)")
            if matchingCachedDepCount != target.dependencies.count {
              try self.updateDependencies(targetId: targetTableId, target: target)
            }
          }

          //let tempArtifacts = TempTargetArtifactTable()
          //try tempArtifacts.insert(target.eArtifacts, self.db)

          //let matchingCachedArtifactCount = try self.db.scalar(
          //  tempArtifacts.table
          //    .join(.inner, self.targetArtifactCaches.table,
          //      on: self.targetArtifactCaches.targetId.qualified == targetTableId
          //       && self.targetArtifactCaches.artifactType.qualified == tempArtifacts.artifactType.qualified)
          //    .count
          //)
          //if matchingCachedArtifactCount != target.eArtifacts.count {
          //  try self.updateArtifacts(targetId: targetTableId, target: target)
          //}
        } else {
          let id = try await self.addTarget(project: project, target: target)
          visitedTargets.append(id)
        }
      }
    }

    let removed = try self.db.prepare(self.targets.table
      .select(self.targets.id.qualified)
      .where(!visitedTargets.contains(self.targets.id.qualified)))

    for removed in removed {
      let removedId = removed[self.targets.id.qualified]
      MessageHandler.debug("Target was removed since last invocation: \(removedId)")
      try self.removeTarget(targetId: removedId)
    }
  }

  fileprivate func insertDependencies(targetId: Int64, target: borrowing AnyTarget) throws {
    if target.dependencies.count == 0 { return }
    let depInserts = try target.dependencies.map { dependency in
      var inserts = [
        self.targetDependencyCaches.targetId.unqualified <- targetId,
        self.targetDependencyCaches.dependencyType.unqualified <- dependency.type,
      ]
      switch (dependency) {
        case .library(let lib):
          inserts.append(self.targetDependencyCaches.dependencyTargetId.unqualified <- try self.getTarget(lib.target)!)
          inserts.append(self.targetDependencyCaches.stringData.unqualified <- nil)
        default:
          inserts.append(self.targetDependencyCaches.dependencyTargetId.unqualified <- nil)
          inserts.append(self.targetDependencyCaches.stringData.unqualified <- dependency.stringValue!)
      }
      return inserts
    }
    try self.db.run(self.targetDependencyCaches.table.insertMany(depInserts))
  }

  //fileprivate func insertArtifacts(targetId: Int64, target: borrowing AnyTarget) throws {
  //  if target.eArtifacts.count == 0 { return }
  //  let artifactInserts = target.eArtifacts.map { artifact in
  //    [
  //      self.targetArtifactCaches.targetId.unqualified <- targetId,
  //      self.targetArtifactCaches.artifactType.unqualified <- artifact,
  //      self.targetArtifactCaches.relink.unqualified <- true
  //    ]
  //  }
  //  try self.db.run(self.targetArtifactCaches.table.insertMany(artifactInserts))
  //}

  fileprivate func addTarget(
    project: borrowing AnyProject,
    target: borrowing AnyTarget
  ) async throws -> Int64 {
    print("adding target \(project.name):\(target.name)")
    let targetId = try self.db.run(self.targets.table
      .insert([
        self.targets.project.unqualified <- project.id,
        self.targets.target.unqualified <- target.id
      ]))

    try self.db.run(self.targetCaches.table
      .insert([
        self.targetCaches.targetId.unqualified <- targetId,
        self.targetCaches.target.unqualified <- target.name,
        self.targetCaches.project.unqualified <- project.name,
        self.targetCaches.targetType.unqualified <- target.type
      ]))

    try self.insertDependencies(targetId: targetId, target: target)
    try self.setShouldRelink(targetId: targetId)
    //try self.insertArtifacts(targetId: targetId, target: target)

    return targetId
  }

  /// Dependencies have changed and they need to be updated
  fileprivate func updateDependencies(
    targetId: Int64,
    target: borrowing AnyTarget
  ) throws {
    try self.db.run(self.targetDependencyCaches.table
      .where(self.targetDependencyCaches.targetId.qualified == targetId)
      .delete())
    try self.insertDependencies(targetId: targetId, target: target)
    print("dependencies changed of \(targetId)")
    try self.setShouldRelink(targetId: targetId)
  }

  //fileprivate func updateArtifacts(
  //  targetId: Int64,
  //  target: borrowing AnyTarget
  //) throws {
  //  try self.db.run(self.targetArtifactCaches.table
  //    .where(self.targetArtifactCaches.targetId.qualified == targetId)
  //    .delete())
  //  try self.insertArtifacts(targetId: targetId, target: target)
  //}

  fileprivate func setShouldRelink(targetId: Int64) throws {
    print("should relink: \(targetId)")
    try self.db.run(self.outputFiles.table
      .where(self.outputFiles.targetId.qualified == targetId)
      .update(self.outputFiles.relink.unqualified <- true))
    //try self.db.run(self.targetArtifactCaches.table
    //  .where(self.targetArtifactCaches.targetId.qualified == targetId)
    //  .update([self.targetArtifactCaches.relink.qualified <- true]))
  }

  //fileprivate func checkProject(
  //  projectName: String,
  //  context: borrowing Beaver
  //) async throws {
  //  if let projectRef = await context.projectRef(name: projectName) {
  //    // Project still exists
  //    try await context.withProject(projectRef) { (project: borrowing AnyProject) in
  //      for targetRow in try self.db.prepare(
  //        self.targets.table.select(
  //          self.targets.id.qualified,
  //          self.targets.project.qualified,
  //          //self.targetCaches.project.qualified,
  //          self.targets.target.qualified,
  //          self.targetCaches.target.qualified
  //        ).join(.inner, self.targetCaches.table, on: self.targetCaches.targetId.qualified == self.targets.id.qualified)
  //          .where(self.targetCaches.project.qualified == projectName)
  //      ) {
  //        try await self.checkTarget(
  //          targetTableId: targetRow[self.targets.id.qualified],
  //          targetName: targetRow[self.targetCaches.target.qualified],
  //          targetIndex: targetRow[self.targets.target.qualified],
  //          projectIndex: targetRow[self.targets.project.qualified],
  //          project: project
  //        )
  //      }
  //    }
  //  } else {
  //    // project was removed
  //    try self.removeProject(projectName: projectName)
  //  }
  //}

  //fileprivate func removeProject(projectName: String) throws {
  //  try self.db.run(self.targets.table
  //    .join(.inner, self.targetCaches.table, on: self.targets.id.qualified == self.targetCaches.targetId.qualified)
  //    .where(self.targetCaches.project.qualified == projectName)
  //    .delete()
  //  )

  //  try self.db.run(self.targetCaches.table
  //    .join(.inner, self.targets.table, on: self.targets.id.qualified == self.targetCaches.targetId.qualified)
  //    .where(self.targetCaches.project.qualified == projectName)
  //    .delete()
  //  )
  //}

  //fileprivate func checkTarget(
  //  /// Target.id
  //  targetTableId: Int64,
  //  targetName: String,
  //  /// The TargetRef.target
  //  targetIndex: Int,
  //  /// The TargetRef.project
  //  projectIndex: Int,
  //  project: borrowing AnyProject
  //) async throws {
  //  if projectIndex != project.id {
  //    // project index has changed (new project was added before this one)
  //    try self.db.run(self.targets.table
  //      .where(self.targets.id.unqualified == targetTableId)
  //      .update([self.targets.project.unqualified <- project.id])
  //    )
  //  }

  //  if let targetRef = await project.targetIndex(name: targetName) {
  //    // Target still exists
  //    try await project.withTarget(targetRef) { (target: borrowing AnyTarget) in
  //      // targetIndex changed (target was inserted before this one in the same project)
  //      if targetIndex != target.id {
  //        try self.db.run(self.targets.table
  //          .where(self.targets.id.unqualified == targetTableId)
  //          .update([self.targets.target.unqualified <- target.id])
  //        )
  //      }


  //    }
  //  } else {
  //    // Target was removed
  //    try self.removeTargetCache(targetTableId: targetTableId)
  //  }
  //}

  //fileprivate func removeTargetCache(
  //  targetTableId: Int64
  //) throws {
  //  try self.db.run(self.targets.table
  //    .where(self.targets.id.unqualified == targetTableId)
  //    .delete())
  //  try self.db.run(self.targetArtifactCaches.table
  //    .where(self.targetArtifactCaches.targetId.unqualified == targetTableId)
  //    .delete())
  //  try self.db.run(self.targetDependencyCaches.table
  //    .where(self.targetDependencyCaches.targetId.unqualified == targetTableId)
  //    .delete())
  //  try self.removeTarget(targetId: targetTableId)
  //}
}


extension AsyncSequence {
  func forEach(_ cb: (Element) async throws -> Void) async rethrows {
    for try await el in self {
      try await cb(el)
    }
  }
}
