Phase Hook
----------

.. rb:function:: pre(phase_name, &proc)

  Register a block of code to run before a phase starts.

  **Example**

  .. code-block:: rb

    pre "build" do
      puts "This runs before every build
    end

.. rb:function:: post(phase_name, &proc)

  Register a block of code to run after a phase ended.

  **Example**

  .. code-block:: rb

    post "test" do
      puts "This runs after tests, can be used to clean up files for example"
    end
