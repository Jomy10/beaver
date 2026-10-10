
- ``"library"``: By default, dependencies are looked for in the current project.
- ``"project:library"``: When a dependency of another project is required,
  this syntax can be used.

See :ref:`dependency` for more functions to create dependencies.

.. - ``dynamic("library")``: Explicitly links to the dynamic artifact of the library.
.. - ``static("library")``: Explicitly links to the static artifact of the library.
.. - ``pkgconfig("library")``: Link to a system library accessible by pkg-config.
.. - ``system_lib("library")``: Link to a system library, this is equivalent to setting
  .. ``-llibray`` in **linker_flags**.
.. - ``framework("library")``: Link to a system framework, this is equivalent to setting
  .. ``"-framework", "library"`` in **linker_flags**.
