require 'beaver'

Project.new("MyProject", build_dir: "out")

C::Library.framework("Foundation")

C::Executable.new(
  name: "MyExecutable",
  language: "Obj-C",
  sources: "src/main.m",
  dependencies: ["Foundation"],
  cflags: []
)

