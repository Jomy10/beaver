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
  var mutCtx = try Beaver()
  await mutCtx.addProject(Project(
    name: "Adder",
    baseDir: URL(filePath: "Tests/resources/exampleCProjectAdder"),
    buildDir: URL(filePath: ".build/tests/exampleCProjectAdder"),
    targets: NonCopyableArray(),
    context: mutCtx
  ))

  try await mutCtx.withCurrentProject { (project: inout Project) in
    _ = await project.addTarget(try CLibrary(
      name: "Adder",
      description: "Adds two numbers",
      artifacts: [.staticlib],
      sources: "adder.c",
      headers: "*.h"
    ))
  }
  let adderDep = try await mutCtx.dependency("Adder")
  try await mutCtx.withCurrentProject { (project: inout Project) in
    _ = await project.addTarget(try CExecutable(
      name: "AdderTest",
      description: "Add two numbers and check the result",
      artifacts: [.executable],
      sources: "main.c",
      dependencies: [adderDep]
    ))
  }

  try mutCtx.finalize()
  let ctx = consume mutCtx
  try await ctx.withCurrentProject { (proj: borrowing Project) in
    try await proj.withTarget(ctx.targetIndex(name: "Adder", project: proj.id)!) { (target: borrowing any Target) in
      try await target.build(baseDir: proj.baseDir, buildDir: proj.buildDir, context: ctx)
    }
    try await proj.withTarget(ctx.targetIndex(name: "AdderTest", project: proj.id)!) { (target: borrowing any Target) in
      try await target.build(baseDir: proj.baseDir, buildDir: proj.buildDir, context: ctx)
    }
  }

  try await ctx.withCurrentProject { (proj: borrowing Project) in
    try await proj.withExecutable(ctx.targetIndex(name: "AdderTest", project: proj.id)!) { (target: borrowing any Executable) in
      try await Tools.exec(target.artifactURL(projectBuildDir: proj.buildDir, ExecutableArtifactType.executable), [])
    }
  }
}
