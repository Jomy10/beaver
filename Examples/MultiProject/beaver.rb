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
  artifacts: [:staticlib],
  sources: "Logger/*.c",
  headers: "Logger"
)

Project(name: "MainProject")

C::Executable(
  name: "Main",
  sources: "*.c",
  dependencies: [
    "Libraries:Logger",
    "Libraries:CXXVec"
  ]
)
