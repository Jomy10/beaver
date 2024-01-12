require 'beaver'

# Import other projects
require_relative 'other/make.rb'

Project.new("MyProject", build_dir: "out/MyProject")

C::Executable.new(
  name: "MyExecutable",
  sources: ["src/main.c"],
  dependencies: ["Other/Hello"],
)

