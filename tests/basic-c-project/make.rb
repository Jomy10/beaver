require 'beaver'

Project.new("MyProject", build_dir: "out")

C::Library.system("pthread")

C::Library.new(
  name: "MyLibrary",
  description: "A description of my library",
  homepage: "https://github.com/jomy10/beaver",
  version: "0.1.0",
  language: "C",
  type: "static",
  sources: "lib/*.c",
  include: { public: "include/public", private: ["include/private"] },
  cflags: { public: "-DMY_LIB_PUB", private: ["-DMY_LIB_PRIV"] },
  dependencies: ["pthread"]
)

# TODO: test pthread can be used in executable
C::Executable.new(
  name: "MyExecutable",
  description: "A description of this executable",
  homepage: "https://github.com/jomy10/beaver",
  version: "0.1.0",
  language: "Mixed",
  sources: ["bin/*.c", "bin/*.cpp"],
  include: "include/bin",
  dependencies: ["MyLibrary"]
)

