Target Accessor
---------------

.. rb:class:: TargetAccessor

  Build, run, or edit targets ad-hoc.

  .. rb:method:: run(args)

    Build and run an executable target.

    :param args: An array of arguments to pass to the executable.

  .. rb:method:: run_thread(args)

    Same as ``run``, but runs the executable on a separate thread.

    :param args: An array of arguments to pass to the executable.
    :rtype: `Thread <https://ruby-doc.org/core-2.5.9/Thread.html>`__.

  .. rb:method:: build

    Build the target (if it needs recompiling).

  .. rb:method:: add_dependency(dependency)

    Add a dependency to the target.

  .. rb:method:: set_pkgconfig(name)

    Set the name of the pkgconfig file, or the path to the pkgconfig file for a Meson target
