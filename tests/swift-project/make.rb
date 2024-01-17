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
    exec.ldflags.push(*Dir["/Library/Developer/CommandLineTools/usr/lib/swift-*/macosx"].map { |p| "-L#{p}"})
    exec.ldflags.push(*Dir["-L/Users/runner/hostedtoolcache/swift-macOS/*/x64/usr/lib/swift/macosx/"].map { |p| "-L#{p}"})
    exec.ldflags.push(*Dir["-L/Applications/Xcode_*.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/lib/swift-5.0/macosx/"].map { |p| "-L#{p}"})
    exec.ldflags.push(*Dir["-L/Applications/Xcode_*.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/lib/macosx/"].map { |p| "-L#{p}"})
  else
    exec.ldflags << "-L/Library/Developer/Toolchains/swift-latest.xctoolchain/usr/lib/swift/macosx"
  end
when :linux
  if ENV["GH_ACTION"] == "1"
    exec.ldflags.push(*Dir["-L/opt/hostedtoolcache/swift-Ubuntu/*/x64/usr/lib"].map { |p| "-L#{p}"})
    exec.ldflags.push(*Dir["-L/opt/hostedtoolcache/swift-Ubuntu/*/x64/usr/lib/swift/linux"].map { |p| "-L#{p}"})
    exec.ldflags.push(*Dir["-L/opt/hostedtoolcache/swift-Ubuntu/*/x64/usr/lib/swift/host"].map { |p| "-L#{p}"})
    exec.ldflags.push(*Dir["-L/opt/hostedtoolcache/swift-Ubuntu/*/x64/usr/lib/swift_static/linux"].map { |p| "-L#{p}"})
  else
    exec.ldflags << "-L/usr/lib/swift"
  end
end

