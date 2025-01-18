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
    static("MyMath"),
    # Link to a library that can be found with pkg-config
    pkgconfig("absl_check")
  ],
  cflags: ["-std=c++14"]
)
