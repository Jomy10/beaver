require 'beaver'

Project.new("MyProject", build_dir: "out")

exec_deps = []
if `uname`.include?("Darwin")
  C::Library.framework("Foundation")
  exec_deps << "Foundation"
end

C::Executable.new(
  name: "MyExecutable",
  language: "Obj-C",
  sources: "src/main.m",
  dependencies: exec_deps,
  cflags: []
)

