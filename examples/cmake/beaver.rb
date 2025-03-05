build_dir "build"

if !Dir.exist? "flatbuffers"
  puts "Cloning flatbuffers..."
  if system("git clone https://github.com/google/flatbuffers") != true
    exit(1)
  end
end

import_cmake "flatbuffers"

puts "Imported flatbuffers"

# TODO: pre "build" do
flatbuffers = project("FlatBuffers")

puts flatbuffers

# Run an executable defined in the FlatBuffers CMake project.
# This will build and run the executable
# TODO: pre "clean" do -> remove .fbs file OR: cleanup(file)
# flatbuffers.run("flatc", "--cpp", "MyFileFormat.fbs")

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
