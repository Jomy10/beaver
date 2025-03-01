build_dir "build"

Project(name: "MyProject")

C::Library(
  name: "MyMathLibrary",
  sources: "math/**/*.c",
  headers: "math",
  artifacts: [:staticlib, :dynlib]
)

C::Executable(
  name: "MyExecutable",
  sources: "src/**/*.c",
  dependencies: ["MyMathLibrary"]
)
