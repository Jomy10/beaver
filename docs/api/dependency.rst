.. _dependency:

Dependency
----------

.. rb:class:: Dependency

  A dependency is used in :ref:`targets <target>` in the ``dependency`` field.

.. rb:function:: static(dependency)

  A dependency on the static artifact of a target.

  :param dependency: The target name.
  :rtype: :rb:class:`Dependency`

.. rb:function:: dynamic(dependency)

  A dependency on the dynamic artifact of a target.

  :param dependency: The target name.
  :rtype: :rb:class:`Dependency`

.. rb:function:: pkgconfig(dependency, version_req, *opts)

  A dependency on a system library which can be retrieved from pkg-config.

  :param dependency: The name of the library in pkg-config.
  :param version_req: Optionally add a version requirement.
  :param opts: Extra options for pkg-config, passed as Symbols.
  :rtype: :rb:class:`Dependency`

    Valid options are:
      - ``:static``: be more aggressive when computing dependency graph (for static linking).

.. rb:function:: pkgconfig_direct(file)

  Evaluate pkg-config from a file.

  :param file: The pkg-config file.
  :rtype: :rb:class:`Dependency`

.. rb:function:: system_lib(name)

  Link to a system library. This is equivalent to adding ``"-lname"`` to the
  linker flags of the target.

  :param name: The name of the system library.
  :rtype: :rb:class:`Dependency`

.. rb:function:: framework(name)

  Link to a system framework. This is equivalent to adding ``"-framework", "name"``
  to the linker flags othe target.

  :param name: The name of the system framework.
  :rtype: :rb:class:`Dependency`

.. rb:function:: flags(flags)

  Create a dependency from flags.

  :param flags: The flags to pass to the dependant.
  :rtype: :rb:class:`Dependency`

    **Example**

    .. code-block:: rb

      flags({
        cflags: ["-DA", "-DB"],
        headers: ["include"],
        linker_flags: ["-lz", "-lcairo"],
      })

.. rb:function:: file_dep(file)

  A file dependency. The target will be rebuilt if the file has changed.

  :param file: The path to the file.
  :rtype: :rb:class:`Dependency`
