import Foundation
import SQLite

extension FileCache {
  func shouldReconfigureCMakeProject(_ dir: URL) throws -> Bool {
    guard let configId = self.configurationId else {
      throw CacheError.noConfigurationSelected
    }

    let cmakeDir = dir.absoluteURL.path

    let cmakeFiles = try self.db.prepare(self.cmakeProjects.table
      .select(self.files.table[*])
      .join(.inner, self.cmakeFiles.table, on: self.cmakeProjects.id.qualified == self.cmakeFiles.cmakeProjectId.qualified)
      .join(.inner, self.files.table, on: self.files.id.qualified == self.cmakeFiles.fileId.qualified)
      .where(self.cmakeProjects.directory.qualified == cmakeDir && self.cmakeProjects.configId.qualified == configId))
      .map { row in FileChecker.fileFromRow(row) }

    for file in cmakeFiles {
      if try FileChecker.fileChanged(file: file).0 {
        return true
      }
    }

    return false
  }

  func storeCMakeFiles(dir: URL, _ inputs: [URL]) throws {
    guard let configId = self.configurationId else {
      throw CacheError.noConfigurationSelected
    }

    let cmakeDir = dir.absoluteURL.path
    let cmakeProjectId = if let cmakeProjectId = try self.db.pluck(self.cmakeProjects.table
      .select(self.cmakeProjects.id.qualified)
      .where(self.cmakeProjects.configId.qualified == configId && self.cmakeProjects.directory.qualified == cmakeDir)
    ) {
      cmakeProjectId[self.cmakeProjects.id.qualified]
    } else {
      try self.db.run(self.cmakeProjects.table
        .insert([
          self.cmakeProjects.configId.unqualified <- configId,
          self.cmakeProjects.directory.unqualified <- cmakeDir
        ]))
    }

    // Insert files
    let lastRowId = try self.files.insertMany(inputs.map { input in
      (input, try FileChecker.fileAttrs(file: input))
    }, self.db)

    // Inset CMake File definitions
    try self.db.run(self.cmakeFiles.table.insertMany(((lastRowId - Int64(inputs.count) + 1)...lastRowId).map { fileId in
      [
        self.cmakeFiles.cmakeProjectId.unqualified <- cmakeProjectId,
        self.cmakeFiles.fileId.unqualified <- fileId
      ]
    }))
  }
}
