# An example of using libraries defined in another project.
# You can also `require_relative "other/beaver.rb"` to import the
# definitions of another project

# Define a buildDir where all targets of all projects will be built
build_dir "build"

# This can also be declared in another file and simply requiring that file (`require_relative "./path/to/file.rb"`)
Project(
  name: "Libraries",
  base_dir: "Libraries"
)

C::Library(
  name: "CXXVec",
  description: "C API to vector of the C++ standard library",
  language: :cxx,
  artifacts: [:staticlib],
  sources: ["CXXVec/*.cpp"],
  include: { public: "CXXVec" }
)

C::Library(
  name: "Logger",
  description: "Logging implementation",
  artifacts: [:staticlib, :dynlib],
  sources: "Logger/*.c",
  include: "Logger"
)

Project(name: "MainProject")

C::Executable(
  name: "Main",
  sources: "main.c",
  dependencies: [
    # Dependencies from other projects are referred to using the project:target syntax
    "Libraries:Logger",
    "Libraries:CXXVec"
  ]
)
