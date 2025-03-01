build_dir "build"

p send(:methods)

Project(name: "MyProject")

C::Library(
  name: "MyMathLibrary",
  sources: "math/**/*.c",
  include: "math",
  artifacts: [:staticlib, :dynlib]
)

C::Executable(
  name: "MyExecutable",
  sources: "src/**/*.c",
  dependencies: [
    # Link to the dynamic library of MyMathLibrary.
    # You can also write `static("MyMathLibrary")` to link to the static library
    # Writing `"MyMathLibrary"` will link to the default artifact
    dynamic("MyMathLibrary"),
    # Link to a library that can be found with pkg-config
    pkgconfig("uuid"),
    # Link to a system library, equal to `-lpthread`
    system("pthread")
  ]
)
