if !Dir.exist? "flatbuffers"
  sh "git clone https://github.com/google/flatbuffers"
end

importCMake "flatbuffers"

project("flatbuffers") do |project|
  project.run("flatc", "--cpp", "MyFileFormat.fbs")
end

Project(name: "MyFileFormat")

C::Library(
  name: "MyFileFormat",
  language: :cpp,
  artifacts: [:staticlib],
  sources: "src/*.cpp",
  # You can find all targets accessible for a CMake target with
  # `beaver list FlatBuffers` or `beaver list --targets` to see all possible targets
  dependencies: ["FlatBuffers:flatbuffers"]
)
