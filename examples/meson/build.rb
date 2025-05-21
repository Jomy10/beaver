build_dir "build"

import_meson "./meson-project"

Project(name: "ImportMesonProjectExample")

C::Executable(
  name: "test",
  language: :c,
  sources: "main.c",
  dependencies: ["MesonProject:library"]
)
