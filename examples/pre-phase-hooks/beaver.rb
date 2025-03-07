build_dir "build"

# Run before building
pre "build" do
  Dir.mkdir("build/generated") unless Dir.exist?("build/generated")
  File.write("build/generated/generated.h", "#define TEXT_MACRO \"I AM GENERATED\"")
end

pre "clean" do
  File.delete("build/generated/generated.h")
end

Project(name: "MyProject")

C::Executable(
  name: "ExeUsingGeneretedFile",
  sources: "main.c",
  headers: { private: "build/generated" },
)
