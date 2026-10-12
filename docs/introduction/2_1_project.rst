.. _2_1_project:

Defining a project
------------------

To start, create a **beaver.rb** script file in the root of your repository.

In order to define :ref:`targets <2_2_target>`, you need to define a project in which
these targets will reside.

To create a beaver project:

.. code-block:: rb

  Project(name: "MyProject")

All paths will be resolved based on the project's base directory, by default this is
the location of the **beaver.rb** script. To set another base directory, you can use
the **base_dir** argument.

.. code-block:: rb

  Project(name: "MyProject", base_dir: "./MyProject")

.. seealso:: API reference :ref:`Project`
