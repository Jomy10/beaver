build_dir "build"

if !Dir.exist? "flatbuffers"
  puts "Cloning flatbuffers..."
  sh "git clone https://github.com/google/flatbuffers"
  # if system("git clone https://github.com/google/flatbuffers") != true
  #   exit(1)
  # end
end

import_cmake "flatbuffers"

# Execute this code before a build (only executed once per invocation)
pre "build" do
  flatbuffers = project("FlatBuffers")

  # Run an executable defined in the FlatBuffers CMake project.
  # This will build and run the executable
  # TODO: pre "clean" do -> remove .fbs file OR: cleanup(file)
  flatc = flatbuffers.target("flatc")
  flatc.run(["--cpp", "MyFileFormat.fbs"])
end

pre "clean" do
  File.delete("MyFileFormat_generated.h") if File.exist?("MyFileFormat_generated.h")
end

Project(name: "MyFileFormat")

C::Executable(
  name: "MyFileFormat",
  language: :cpp,
  sources: "src/*.cpp",
  # `beaver list` to see all possible targets
  dependencies: ["FlatBuffers:flatbuffers"],
  cflags: ["-std=c++11"]
)
