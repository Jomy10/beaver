Cache
------

.. rb:function:: files_changed(files)

  Check if any of the files changed since the last invocation of this command

  :param files: An array of files to check.
  :rtype: Boolean

.. rb:function:: store(name, val)

  Store a variable in cache.

  :param name: The name of the variable
  :param val: The value to set the variable to

.. rb:function:: get(name)

  Get the value of a variable stored in cache. Can be used to check if
  the variable changed during between compilations.

  :param name: The name of the variable.
