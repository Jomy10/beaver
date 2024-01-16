require 'beaver'

package = SPMProject.new(path: "TestPackage")
package.targets["TestPackage"].flags.push(*["-Xswiftc", "-DHELLO"])

Project.new("MyProject")

C::Executable.new(
  name: "using-swift-lib",
  sources: "src/main.c",
  dependencies: ["TestPackage/TestPackage"],
  ldflags: [
    case $beaver.host_os
    when :macos
      "-L/Library/Developer/Toolchains/swift-latest.xctoolchain/usr/lib/swift/macosx"
    end
  ]
)

