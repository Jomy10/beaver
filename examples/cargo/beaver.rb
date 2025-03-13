build_dir "build"

import_cargo "hello-world"

Project(name: "TestCargo")

C::Executable(
  name: "TestCargo",
  sources: ["main.c"],
  dependencies: ["hello-world:hello_world"]
)
