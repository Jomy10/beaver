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

# case $beaver.host_os
# when :macos
#   if ENV["GH_ACTION"] == "1"
#     for root in ["Users/runner", "Applications", "/Library/Developer/CommandLineTools"]
#       exec.ldflags.push(*Dir["/#{root}/**/*swift*/**/macosx/"].map { |p| "-L#{p}"})
#       exec.ldflags.push(*Dir["/#{root}/**/*swift*/**/lib/"].map { |p| "-L#{p}"})
#     end
#   else
#     exec.ldflags << "-L/Library/Developer/Toolchains/swift-latest.xctoolchain/usr/lib/swift/macosx"
#   end
# when :linux
#   if ENV["GH_ACTION"] == "1"
#     exec.ldflags.push(*Dir["/opt/**/lib"].map { |p| "-L#{p}"})
#     exec.ldflags.push(*Dir["/opt/**/lib/swift/linux"].map { |p| "-L#{p}"})
#     exec.ldflags.push(*Dir["/opt/**/lib/swift/host"].map { |p| "-L#{p}"})
#     exec.ldflags.push(*Dir["/opt/**/lib/swift_static/linux"].map { |p| "-L#{p}"})
#   else
#     exec.ldflags << "-L/usr/lib/swift"
#   end
# end
#
