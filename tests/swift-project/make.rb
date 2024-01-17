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
    exec.ldflags << "-L/opt/hostedtoolcache/swift-Ubuntu/*/x64/usr/lib"
    exec.ldflags << "-L/opt/hostedtoolcache/swift-Ubuntu/*/x64/usr/lib/swift/linux"
    exec.ldflags << "-L/opt/hostedtoolcache/swift-Ubuntu/*/x64/usr/lib/swift/host"
    exec.ldflags << "-L/opt/hostedtoolcache/CodeQL/*/x64/codeql/swift/resource-dir/linux64/linux"
  else
    exec.ldflags << "-L/usr/lib/swift"
  end
end

