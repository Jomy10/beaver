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

case $beaver.host_os
when :macos
  exec.ldflags << "-L/Library/Developer/Toolchains/swift-latest.xctoolchain/usr/lib/swift/macosx"
when :linux
  if ENV["GH_ACTION"] == "1"
    exec.ldflags << "-L/opt/hostedtoolcache/swift-Ubuntu/5.9.2/x64/usr/lib/swift/linux/"
    exec.ldflags << "-L/opt/hostedtoolcache/swift-Ubuntu/5.9.2/x64/usr/lib/swift/host"
  else
    exec.ldflags << "-L/usr/lib/swift"
  end
end

