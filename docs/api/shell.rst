Shell
------

Different functions exist to enrich the beaver build system with your own
commands, options and flags.

.. rb:function:: opt(long_name, short_name = nil, default:)

  Define an option that can be passed to the command line. The return value
  is what is passed on the command line

  :param long_name: The option name to be used on the command line, preceded by ``--``.
  :param short_name: Optionally a short name of 1 letter as an alias for the option,
    on the command line preceded by ``-``.
  :param: default: A default value if the option is not specified on the command line.
  :returns: The value passed on the command line.
  :rtype: Return type depends on the default value. If no default value is passed, the
    return type will be a String.

  **Example**

  .. code-block:: rb

    value = opt("option", "o", default: 1)

  .. code-block:: sh

    $ beaver -- --option=5
    $ beaver -- -o4
    $ beaver -- -o 3

.. rb:function:: flag(long_name, short_name = nil, default:)

  Define a flag on the command line that evaluates to true or false.
  The flag can be negated by preceding it with "no-".

  :param long_name: The option name to be used on the command line, preceded by ``--``.
  :param short_name: Optionally a short name of 1 letter as an alias for the option,
    on the command line preceded by ``-``.
  :param: default: A default value if the option is not specified on the command line.
  :rtype: Boolean

  **Example**

  .. code-block:: rb

    value = flag("has-cairo")
    puts value

  .. code-block:: sh

    $ beaver -- --has-cairo
    true
    $ beaver -- --no-has-cairo
    false

.. rb:function:: cmd(name, &command)

  Define a command. Commands can be called from the command line just like the
  standard "run" or "test" commands.

  The first command defined is also the default command.
  :param name: The name on the command. This is how it is called from the command line.
  :param command: A code block to execute when the command is called.

  **Example**

  .. code-block:: rb

    cmd "hello-world" do
      puts "Hello world"
    end

  .. code-block:: sh

    $ beaver hello-world
    Hello world

Utilities
==========

.. rb:function:: sh(*args)

  The ``sh`` function prints out the shell command it runs and then executes it.
  When an error occurs in the shell command, it raises an exception.

  :param args: The shell command.

  **Example**

  .. code-block:: rb

    # We can pass a string to the sh function containing the command
    sh "echo 'Hello world!'"

    # Or we can pass an array with each argument individually, beaver will then
    # automatically quote all the arguments
    sh "echo" "Hello world!"

.. rb:function:: split_args(args)

  Turns a string of arguments into an array of arguments as would be parsed by the shell.

  :param args: The arguments to split.

  **Example**

  .. code-block:: rb

    split_args("a b 35 'Hello World'")
    #=> ["a", "b", "35", "Hello World"]
