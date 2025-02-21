Project(name: "MyProject")

C::Library(
  name: "MyMath",
  artifacts: [:staticlib, :dynlib],
  sources: "Math/MyMath.c",
  headers: ["Math"]
)

C::Executable(
  name: "Main",
  language: :cxx,
  sources: "main.cpp",
  dependencies: [
    # Link to the static library artifact of the Math target
    # If you want dynamic linking, you can write `dynamic("MyMath")`
    # Just writing "MyMath" will select the default. This is static for targets in the same project and dynamic for other targets
    static("MyMath"),
    # Link to a library that can be found with pkg-config
    pkgconfig("uuid"),
    # Link to a system library; -lpthread
    system("pthread")
  ],
  cflags: ["-std=c++14"]
)
