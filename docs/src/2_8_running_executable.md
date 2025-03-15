# Running executables

Executable defined inside of a project (user-defined or imported) can be run inside
of the script.

**example**: We'll import FlatBuffers (a CMake project), run the executable `flatc`
inside of this project, which generates a header file. Then we'll make this header file
to our executable.

```ruby
build_dir "build"

# Clone FlatBuffers repository if it is not yet present
sh "git clone https://github.com/google/flatbuffers" unless Dir.exist? "flatbuffers"

# Import the FlatBuffers project
import_cmake "./flatbuffers"

# Before a build, we'll generate the header
pre "build" do
  # get the FlatBuffers project (see `beaver list`)
  flatbuffers = project("FlatBuffers")

  flatc = flatbuffers.target("flatc")
  flatc.run(["--cpp", "FileFormatDefinition.fbs", "-o", "build"])
end

# Before a clean, delete the generated file
pre "clean" do
  File.delete("build/FileFormatDefinition_generated.h")
end

Project(name: "MyProject")

C::Executable(
  name: "main",
  language: :cpp,
  sources: "src/*.cpp",
  # Include the generated header
  headers: { private: "build" },
  dependencies: ["FlatBuffers:flatbuffers"],
  cflags: ["-std=c++11"]
)
```
