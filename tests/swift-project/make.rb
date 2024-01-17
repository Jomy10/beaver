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
  if ENV["GH_ACTION"] == "1"
    exec.ldflags << "-L/Library/Developer/CommandLineTools/usr/lib/swift-*/macosx"
    # /System/Volumes/Data/Users/runner/hostedtoolcache/swift-macOS/5.9.2/x64/usr/lib/swift/macosx/
    # /System/Volumes/Data/Applications/Xcode_14.2.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/lib/swift-5.0/macosx/
  else
    exec.ldflags << "-L/Library/Developer/Toolchains/swift-latest.xctoolchain/usr/lib/swift/macosx"
  end
when :linux
  if ENV["GH_ACTION"] == "1"
    exec.ldflags << "-L/opt/hostedtoolcache/swift-Ubuntu/*/x64/usr/lib"
    exec.ldflags << "-L/opt/hostedtoolcache/swift-Ubuntu/*/x64/usr/lib/swift/linux"
    exec.ldflags << "-L/opt/hostedtoolcache/swift-Ubuntu/*/x64/usr/lib/swift/host"
    exec.ldflags << "-L/opt/hostedtoolcache/CodeQL/*/x64/codeql/swift/resource-dir/linux64/linux"
    exec.ldflags << "-L/opt/hostedtoolcache/swift-Ubuntu/5.9.2/x64/usr/lib/swift_static/linux"
  else
    exec.ldflags << "-L/usr/lib/swift"
  end
end

