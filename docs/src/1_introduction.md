# Beaver

Beaver is a build system that can be configured using a ruby script.
It support multiple languages, handling the linking between these languages and allows
you to import projects from other build systems.

Beaver is focussed on readability and correctness.

## Basic example

```ruby
Project(name: "Game")

C::Library(
  name: "Physics",
  description: "Physics simulation library",
  language: :cpp,
  sources: "lib/physics/*.cpp",
  include: "include/physics"
)

C::Library(
  name: "Renderer",
  language: :c,
  sources: "lib/renderer/*.c",
  include: "include/renderer",
  dependencies: [
    pkgconfig("SDL2"),
    system_lib("pthread")
  ]
)

C::Executable(
  name: "Game",
  language: :cpp,
  sources: "src/*.cpp",
  dependencies: ["Physics", "Renderer"]
)
```

Many more examples can be found on [GitHub](https://github.com/jomy10/beaver/tree/master/examples).
