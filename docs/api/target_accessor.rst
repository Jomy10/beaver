.. _TargetAccessor:

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

  .. rb:method:: artifacts

    Returns the artifacts that this target outputs.

    :rtype: Hash where the key is an artifact type and the value is the path to the artifact

    **Example**

    .. code-block:: rb

      project("SomeProject").target("SomeTarget").artifacts
      #=> {
      #     staticlib: "build/aarch64-apple-darwin/debug/SomeTarget/artifacts/libSomeTarget.a",
      #     dynlib: "build/aarch64-apple-darwin/debug/SomeTarget/artifacts/libSomeTarget.dylib"
      #   }

  .. rb:method:: dep(artifact_type)

    Returns a dependency to the `artifact_type` of this target.

    :param artifact_type: The type of artifact to get the dependency to (e.g. ``:staticlib``, ``:dynlib``, ...)
    :rtype: :rb:class:`Dependency`

    **Example**

    .. code-block:: rb

      some_target = project("SomeProject").target("SomeTarget")

      C::Library(
        # ...
        dependencies: [
          some_target.dep(:staticlib)
        ]
      )
