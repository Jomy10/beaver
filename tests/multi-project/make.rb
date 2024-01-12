require 'beaver'

Project.new("Other", build_dir: "out/other")

C::Library.new(
  name: "MyLibrary",
  sources: "lib/*.c",
  include: "include"
)

Project.new("MyProject", build_dir: "out/MyProject")

C::Executable.new(
  name: "MyExecutable",
  sources: "bin/*.c",
  dependencies: ["Other/MyLibrary"]
)

