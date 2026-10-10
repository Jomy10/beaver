Optimization
-------------

.. rb:const:: OPT

  The optimization mode.

  Can be used to set flags depending on the optimization mode, e.g.

  .. code-block:: rb

    if OPT == "release"
      cflags << "-DNO_PRINT"
    end
