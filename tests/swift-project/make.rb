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
    exec.ldflags.push(*Dir["-L/**/macosx/"].map { |p| "-L#{p}"})
    exec.ldflags.push(*Dir["-L/**/lib/"].map { |p| "-L#{p}"})
  else
    exec.ldflags << "-L/Library/Developer/Toolchains/swift-latest.xctoolchain/usr/lib/swift/macosx"
  end
when :linux
  if ENV["GH_ACTION"] == "1"
    exec.ldflags.push(*Dir["-L/**/lib"].map { |p| "-L#{p}"})
    exec.ldflags.push(*Dir["-L/**/lib/swift/linux"].map { |p| "-L#{p}"})
    exec.ldflags.push(*Dir["-L/**/lib/swift/host"].map { |p| "-L#{p}"})
    exec.ldflags.push(*Dir["-L/**/lib/swift_static/linux"].map { |p| "-L#{p}"})
  else
    exec.ldflags << "-L/usr/lib/swift"
  end
end

