require 'beaver'

Project.new("Other", build_dir: "../out/Other")

C::Library.new(
  name: "Hello",
  sources: ["src/*.c"]
)

