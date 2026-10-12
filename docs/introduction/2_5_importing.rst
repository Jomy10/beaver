.. _2_5_importing:

Importing projects
------------------

Importing beaver projects
=========================

Importing another beaver project can be done by simple requiring it:

.. code-block:: rb

  require_relative "path/to/other/project/beaver.rb"

  Project(name: "MyProject")

  # ...

Importing projects from other build systems
===========================================

Projects from other build systems can be imported into beaver. This is done with
the function ``import_{build-system-name}``.

Currently supported build systems:
  - CMake: ``import_cmake [path-to-project] [cmake-configure-arguments]``
  - Meson: ``import_meson [path-to-project] [meson-configure-arguments] [extra-file-depencies]``
  - Cargo: ``import_cargo [path-to-project]``
  - Swift Package Manager: ``import_spm [path-to-project]``

.. code-block:: rb

  import_cmake "./flatbuffers"

  Project(name: "MyProject")

  C::Executable(
    name: "uses_flatbuffers",
    language: :cpp,
    sources: "src/**/*.cpp",
    dependencies: ["FlatBuffers:flatbuffers"],
    cflags: ["-std=c++11"]
  )

.. code-block:: sh

  $ beaver list
  FlatBuffers
    flatbuffers
    flatc
    flatsamplebfbs
    flatsamplebinary
    flatsampletext
    flattests
  MyProject
    uses_flatbuffers


.. ## Importing remote projects

.. **Unimplemented**

.. In the future beaver will be able to manage dependencies from remote hosts,
.. automatically downloading the right version, etc.
