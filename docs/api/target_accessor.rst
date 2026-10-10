Target Accessor
---------------

.. rb:class:: TargetAccessor

  Build, run, or edit targets ad-hoc.

  .. rb:classmethod:: run(args)

    Build and run an executable target.

    :param args: An array of arguments to pass to the executable.

  .. rb:classmethod:: run_thread(args)

    Same as ``run``, but runs the executable on a separate thread.

    :param args: An array of arguments to pass to the executable.
    :rtype: `Thread <https://ruby-doc.org/core-2.5.9/Thread.html>`__.

  .. rb:classmethod:: build

    Build the target (if it needs recompiling).

  .. rb:classmethod:: add_dependency(dependency)

    Add a dependency to the target.

  .. rb:classmethod:: set_pkgconfig(name)

    Set the name of the pkgconfig file, or the path to the pkgconfig file for a Meson target
