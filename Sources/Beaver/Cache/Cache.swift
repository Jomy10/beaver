import Foundation

// TODO: implement
struct Cache {

  init(_ cacheFile: URL) {
    print("TODO: init cache")
  }

  mutating func selectConfiguration(mode: OptimizationMode) throws {
    print("TODO: select config")
  }

  func shouldReconfigureCMakeProject(_ cmakeBaseDir: URL) throws -> Bool {
    fatalError("TODO")
  }

  func storeCMakeFiles(dir cmakeBaseDir: URL, _ files: [URL]) throws {
    fatalError("TODO")
  }

  // User-defined //

  func fileChanged(file: URL, context: String) throws -> Bool {
    fatalError("TODO")
  }

  func getVar(name: String) throws -> CacheVarVal {
    fatalError("TODO")
  }

  func setVar(name: String, value: CacheVarVal) throws {
    fatalError("TODO")
  }

  func configChanged(context: String) throws -> Bool {
    fatalError("TODO")
  }
}

public enum CacheVarVal {
  case string(String)
  case int(Int)
  case double(Double)
  case bool(Bool)
  /// All non-existant cache variables are implicitly nil
  case none

  //func asEntry(withName name: String) -> CustomVariable {
  //  switch (self) {
  //    case .string(let s): CustomVariable(name: name, strVal: s)
  //    case .int(let i): CustomVariable(name: name, intVal: i)
  //    case .double(let d): CustomVariable(name: name, doubleVal: d)
  //    case .bool(let b): CustomVariable(name: name, boolVal: b)
  //    case .none: CustomVariable(name: name)
  //  }
  //}

  //init(fromEntry entry: CustomVariable) {
  //  if let strVal = entry.strVal {
  //    self = .string(strVal)
  //  } else if let intVal = entry.intVal {
  //    self = .int(intVal)
  //  } else if let doubleVal = entry.doubleVal {
  //    self = .double(doubleVal)
  //  } else if let boolVal = entry.boolVal {
  //    self = .bool(boolVal)
  //  } else {
  //    self = .none
  //  }
  //}
}
