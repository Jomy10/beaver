require 'beaver'

package = SPMProject.new(path: "TestPackage")
package.targets["TestPackage"].flags.push(*["-Xswiftc", "-DHELLO"])

system "pwd"
Project.new("MyProject")

exec = C::Executable.new(
  name: "using-swift-lib",
  sources: "src/main.c",
  dependencies: ["TestPackage/TestPackage"],
  ldflags: []
)

require 'json'
target_info = JSON.parse(`swiftc -print-target-info`)

exec.ldflags.push(*target_info["paths"]["runtimeLibraryPaths"].map { |path| "-L#{path}" })
exec.ldflags.push(*target_info["paths"]["runtimeLibraryImportPaths"].map { |path| "-L#{path}" })

