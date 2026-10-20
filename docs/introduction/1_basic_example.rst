Basic example
-------------

.. code-block:: rb

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

Many more examples can be found on `CodeBerg <https://codeberg.org/Jomy10/beaver/src/branch/master/examples>`_ (`mirror <https://github.com/jomy10/beaver/tree/master/examples>`_).
