require 'beaver'

package = SPMProject.new(path: "TestPackage")
package.targets["TestPackage"].flags.push(*["-Xswiftc", "-DHELLO"])

Project.new("MyProject")

exec = C::Executable.new(
  name: "using-swift-lib",
  sources: "src/main.c",
  dependencies: ["TestPackage/TestPackage"],
  ldflags: []
)

