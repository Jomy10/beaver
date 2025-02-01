buildDir "build"

if !Dir.exist? "flatbuffers"
  sh "git clone https://github.com/google/flatbuffers"
end

importCMake "flatbuffers"

# TODO: pre "build" do
flatbuffers = project("FlatBuffers")
# Run an executable defined in the FlatBuffers CMake project.
# This will build and run the executable
flatbuffers.run("flatc", "--cpp", "MyFileFormat.fbs")

Project(name: "MyFileFormat")

C::Executable(
  name: "MyFileFormat",
  language: :cpp,
  sources: "src/*.cpp",
  # You can find all targets accessible for a CMake target with
  # `beaver list FlatBuffers` or `beaver list --targets` to see all possible targets
  dependencies: ["FlatBuffers:flatbuffers"],
  cflags: ["-std=c++11"]
)
