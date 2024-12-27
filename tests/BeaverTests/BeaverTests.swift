import Testing
import Foundation
import Semver
import Platform
@testable import Beaver

@Test func nonCopyableArray() async throws {
  var array = NonCopyableArray<String>()
  array.append("Hello")
  array.append("world")
  let arrayMoved = array.appending("!")
  var i = 0
  arrayMoved.forEach { (element: borrowing String) in
    switch (i) {
      case 0:
        #expect(element == "Hello")
        i += 1
      case 1:
        #expect(element == "world")
        i += 1
      case 2:
        #expect(element == "!")
        i += 1
      default:
        fatalError("Too many elements")
    }
  }
}

/// Compile a simple C project with one library and an executable depending on the
/// library. Run the executable, which tests the implementation
@Test func exampleCProjectAdder() async throws {
  var mutCtx = Beaver()
  await mutCtx.addProject(Project(
  name: "Adder",
  baseDir: URL(filePath: "Tests/BeaverTests/resources/exampleCProjectAdder"),
  buildDir: URL(filePath: ".build/tests/exampleCProjectAdder"),
  targets: NonCopyableArray()
    .appending(CLibrary(
      name: "Adder",
      description: "Adds two numbers",
      artifacts: [.staticlib],
      sources: "adder.c",
      headers: "*.h"
    ))
    .appending(CExecutable(
      name: "AdderTest",
      description: "Add two numbers and check the result",
      artifacts: [.executable],
      sources: "main.c",
      dependencies: [try .init("Adder", defaultProject: 0, context: mutCtx)]
    ))
  ))

  let ctx = consume mutCtx
  try await ctx.withCurrentProject { (proj: borrowing Project) in
    try await proj.withTarget(named: "Adder") { (target: borrowing any Target) in
      try await target.build(baseDir: proj.baseDir, buildDir: proj.buildDir, context: ctx)
    }
    try await proj.withTarget(named: "AdderTest") { (target: borrowing any Target) in
      try await target.build(baseDir: proj.baseDir, buildDir: proj.buildDir, context: ctx)
    }
  }

  try await ctx.withCurrentProject { (proj: borrowing Project) in
    try await proj.withExecutable(named: "AdderTest") { (target: borrowing any Executable) in
      try await Tools.exec(target.artifactURL(projectBuildDir: proj.buildDir, ExecutableArtifactType.executable), [])
    }
  }
}

@Test func multiProject() async throws {
  var mutCtx = Beaver()
  await mutCtx.addProject(Project(
    name: "Logger",
    baseDir: URL(filePath: "Tests/BeaverTests/resources/multiProject/Logger"),
    buildDir: URL(filePath: ".build/tests/multiProject/Logger")
  ))
  try await mutCtx.withCurrentProject { (proj: inout Project) in
    await proj.addTarget(CLibrary(
      name: "Logger",
      description: "Logging implementation",
      artifacts: [.staticlib],
      sources: ["logger.c"],
      headers: Headers(public: [proj.baseDir])
    ))
  }

  await mutCtx.addProject(Project(
    name: "Main",
    baseDir: URL(filePath: "Tests/BeaverTests/resources/multiProject/Main"),
    buildDir: URL(filePath: ".build/tests/multiProject/Main")
  ))
  let loggerDep: LibraryRef = try await LibraryRef("Logger:Logger", defaultProject: mutCtx.currentProjectIndex!, context: mutCtx)
  try await mutCtx.withCurrentProject { (proj: inout Project) in
    await proj.addTarget(CExecutable(
      name: "Main",
      sources: "*.c",
      dependencies: [loggerDep]
    ))
  }

  let ctx = consume mutCtx
  try await ctx.build("Main")

  try await ctx.withCurrentProject { (proj: borrowing Project) in
    try await proj.withExecutable(named: "Main") { (target: borrowing any Executable) in
      try await Tools.exec(target.artifactURL(projectBuildDir: proj.buildDir, .executable), [])
    }
  }
}
