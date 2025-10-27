build_dir "build"

Project(name: "MyProject")

Custom::Library(
  name: "SomeLibrary",
  language: :c,
  cflags: ["-std=c11", "-DHAVE_SOME_LIB"],
  artifacts: {
    staticlib: "build/libsomelib.a"
  },
  build: proc {
    puts "Building SomeLibrary"
    sh "clang -c lib.c -o build/lib.o"
    sh "ar -rcs build/libsomelib.a build/lib.o"
  }
)

C::Executable(
  name: "Test",
  sources: "main.c",
  dependencies: ["SomeLibrary"]
)
