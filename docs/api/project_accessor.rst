Project Accessor
-----------------

.. rb:class:: ProjectAccessor

  Class for accessing a project from ruby.

  .. rb:method:: target(name)

    Get a target from defined in the project.

    :param name: The target name
    :rtype: :rb:class:`TargetAccessor`

  .. rb:method:: build_dir()

    Returns the project's build directory.

    see :rb:func:`Project` name parameter

    :rtype: String

  .. rb:method:: base_dir()

    Returns the project's base directory.

    see :rb:func:`Project` base_dir parameter

    :rtype: String

  .. rb:method:: name()

    Returns the project's name.

    :rtype: String

.. rb:function:: project(name)

  Get the `ProjectAccessor` for a project by its name.

  :param name: The name of the project.
  :rtype: :rb:class:`ProjectAccessor`

.. rb:function:: current_project()

  Get the `ProjectAccessor` for the current project. The current
  project is always the one last created, usually the project the
  user is working on.

  :rtype: :rb:class:`ProjectAccessor`
