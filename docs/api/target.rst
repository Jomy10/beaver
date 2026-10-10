.. _target:

Target
-------

C
==

C targets support C, C++, Obj-C and Obj-C++ sources, depending on the selected **language**.

.. rb:module:: C

.. |c_lang| replace:: Can be C, C++, Obj-C, Obj-C++. Default is C.
.. |c_cflags_brief| replace:: The cflags to compile the source files with.
.. |c_headers_brief| replace:: The path(s) to the directories containing the header files.
.. |c_lflags_brief| replace:: Can be passed as a string (``"-lz"``), or an array (``["-lz", "-lcairo"]``).
.. |c_artifacts_brief| replace:: The artifacts to create.

.. this is a method, but `const` correctly formats it
.. rb:const:: Library(name:, description:, homepage:, version:, license:, language:, sources:, cflags:, headers:, linker_flags:, artifacts:, dependencies:, settings:)

  Define a C library in the current project.

  :param name: The name of the library. Used to identify the target in the project
    and for the name(s) of the output artifact(s). **(required)**
  :param description: A description of the library. Used in pkg-config generation.
  :param homepage: A link to the library's homepage
  :param version: The version of the library. Used in pkg-config generation.
  :param license: The license of the library.
  :param language: The language of the library. |c_lang|
  :param sources: The source files to compile for this library. Supports glob patterns. **(required)**
  :param cflags: |c_cflags_brief|

    Valid forms are
      - a string (``"-DFLAG"``)
      - an array (``["-fsanitize=address", "-fno-omit-frame-pointer"]``)
      - a hash (``{ public: "-DHAVE_X", private: "-D_HAVE_Y" }``).

    When using a hash, **public** flags are passed to targets using the library,
    while **private** flags are not. A string or an array are public flags by default.

  :param headers: |c_headers_brief| These are passed to targets having this library as a dependency.
    They are also passed as cflags when compiling this library as ``-Ipath``.

    This can be
      - a string (``"include"``)
      - an array (``["include", "include2"]``)
      - a hash (``{ public: "include/lib", private: ["include/private", "include/internal"] }``).

    When using a string or array, the include flags are automatically passed to dependants of the
    library. With a hash, you can set internal include flags.

    *alias*: ``include``

  :param linker_flags: |c_lflags_brief|
    Linker flags are automatically passed to dependants of the library.

    *alias*: ``ldflags``, ``lflags``

  :param artifacts: |c_artifacts_brief|

    The following artifacts can be created:
      - ``dynlib``
      - ``staticlib``: When compiling for WebAssembly, this is a wasm file.
      - ``pkgconfig``
      - ``framework``
      - ``xcframework``
      - ``jslib``: Only when compiling for wasm, this creates a JavaScript file
        that binds the wasm file created.

  :param dependencies: An array of libraries this library requires.

    .. include:: target_c_dep.rst

  :param settings:

    .. include:: target_c_settings.rst


.. rb:const:: Executable(name:, description:, homepage:, version:, license:, language:, sources:, cflags:, headers:, linker_flags:, artifacts:, dependencies:, settings:)

  Define a C executable in the current project.

  :param name: The name of the executable. Used to identify the target in the project
    and for the name(s) of the output artifact(s). **(required)**
  :param description: A description of the executable.
  :param homepage: A link to the executable's homepage.
  :param version: The version of the executable.
  :param license: The license of the executable.
  :param language: The language of the executable. |c_lang|
  :param sources: The source files to compile for this executable. Supports glob patterns. **(required)**
  :param cflags: |c_cflags_brief|
  :param headers: |c_headers_brief| They are passed as cflags when compiling this executable as ``-Ipath``.
  :param linker_flags: |c_lflags_brief|

  :param artifacts: |c_artifacts_brief|

    The following artifacts can be created:
      - ``"exe"``: A standard executable.
      - ``"App"``: A macOS app.

  :param dependencies: An array of libraries this executable requires.

    .. include:: target_c_dep.rst

  :param settings:

    .. include:: target_c_settings.rst

Custom
=======

Custom targets can be used to use arbitrary build commands (like libraries using `make`) to
build Beaver-compatible libraries and executables.

.. rb:module:: Custom

.. rb:const:: Library(name:, description:, homepage:, version:, license:, language:, sources:, cflags:, headers:, linker_flags:, artifacts:, dependencies:, build:)

  Define a custom library.

  :param name: The name of the library.
  :param description: The description of the library.
  :param homepage: A link to the homepage of the library.
  :param version: The version of the library.
  :param license: The license of the library.
  :param language: The source language of the library.
  :param cflags: The C flags of this library. Passed to dependants of this library.
  :param linker_flags: The linker flags of this library. Passed to descendants of this library.

    **alias**: ``linker_flags``, ``ldflags``, ``lflags``

  :param artifacts: Paths to the artifacts the build command generates.

    **Example**

    .. code-block:: rb

      {
        "staticlib": "/path/to/lib.a",
        "dynlib": "/path/to/lib.so"
      }

  :param dependencies: The libraries this library depends on.

    .. include:: target_c_dep.rst

  :param build: The build command.

    **Example**

    .. code-block:: rb

      Custom::Library(
        name: "mylib",
        language: :c,
        artifacts: {
          staticlib: "build/libmylib.a"
        },
        build: proc {
          sh "clang -c lib.c -o build/lib.o"
          sh "ar -rcs build/libmylib.a build/lib.o"
        }
      )

.. Executable...
