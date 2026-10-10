Project
-------------

.. rb:function:: Project(name:, base_dir:)

  Define a new project.

  :param name: A name for the project.
  :param base_dir: The project's directory, where build.rb is located (default: script directory).
  :rtype: :rb:class:`ProjectAccessor`

.. rb:function:: import_cmake(dir, flags)

  Import a CMake project.

  :param dir: The directory of the CMake project.
  :param flags: An array of flags to pass to CMake

.. rb:function:: import_meson(dir, flags, dependency_files)

  Import a Meson project.

  :param dir: The directory of the Meson project (where meson.build lives).
  :param flags: An array of flags to pass to `meson configure`
  :param dependency_files: An array of files to additionally depend on.
    When one of these files changes, the meson project is reconfigured.

    For example, when using ``--cross-file``, the ``crossfile.ini`` can be
    passed here to reconfigure the meson project when the crossfile has changed.

  **Example**

  .. code-block:: rb

      ini_file = File.absolute_path("emscripten.ini")
      import_meson "./deps/cairo", ["--cross-file", ini_file], [ini_file]

.. rb:function:: import_cargo(dir)

  Import a Cargo project.

  :param dir: The path to the Cargo project (where cargo.toml lives).

.. rb:function:: import_spm(dir)

  Import a Swift Package Manager project.

  :param dir: The path to the SPM project (where Package.swift lives).
