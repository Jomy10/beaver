# An example of using libraries defined in another project.
# You can also `require_relative "other/beaver.rb"` to import the
# definitions of another project

# This can also be declared in another file and simple requiring that file (`require_relative "./path/to/file.rb"`)
Project(
  name: "Libraries",
  baseDir: "Libraries"
)

C::Library(
  name: "CXXVec",
  description: "C API to vector of the C++ standard library",
  language: :cxx,
  artifacts: [:staticlib],
  sources: ["CXXVec/*.cpp"],
  headers: { public: "CXXVec" }
)

C::Library(
  name: "Logger",
  description: "Logging implementation",
  artifacts: [:staticlib, :dynlib],
  sources: "Logger/*.c",
  headers: "Logger"
)

Project(name: "MainProject")

C::Executable(
  name: "Main",
  sources: "main.c",
  dependencies: [
    "Libraries:Logger",
    "Libraries:CXXVec"
  ]
)
