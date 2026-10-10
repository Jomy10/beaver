Target Triple
---------------

.. rb:class:: Triple

  A target triple defines a platform.

  .. seealso:: `What the Hell Is a Target Triple? <https://mcyoung.xyz/2025/04/14/target-triples/>`_

  .. rb:classmethod:: to_s

    Convert the target triple to a string. Will return for example ``"wasm32-unknown-emscripten"``.

    :rtype: String

  .. rb:classmethod:: arch

    Gets the architecture of the platform.

    **Example**: x86_64-unknown-freebsd -> x86_64

    :rtype: String

  .. rb:classmethod:: vender

    Gets the vendor of the platform.

    **Example**: aarch64-apple-ios -> apple

    :rtype: String

  .. rb:classmethod:: os

    Gets the operating system of the platform.

    **Example**: aarch64-unknown-linux -> linux

    :rtype: String

  .. rb:classmethod:: abi

    Gets the binary interface of the platform.

    **Example**: x86_64-unknown-linux-gnu -> gnu

    :rtype: String

  .. rb:classmethod:: binary_format

    Gets the binary format of the platform.

    :rtype: String

  .. rb:classmethod:: endianness

    Gets the endianness of the platform. This can be ``:little`` or ``:big``.

    :rtype: Symbol

  .. rb:classmethod:: pointer_width

    Gets the size of a pointer on the platform as a number of bytes.

    :rtype: Integer

  .. rb:classmethod:: posix?

    Returns true for posix and mostly posix-compliant operating systems.

    :rtype: Boolean

  .. rb:classmethod:: posix_certified?

    Returns true if the linux is posix certified.

    :rtype: Boolean

  .. rb:classmethod:: darwin?

    Return true if the platform is a darwin platform (e.g. macOS, iOS, tvOS, ...).

    :rtype: Boolean

Constants
==========

.. rb:const:: TARGET

  The platform compiling to.

  Can be used for conditional compilation, e.g.

  .. code-block:: rb

    if TARGET.os == "emscripten"
      # ...
    end

  :rtype: :rb:class:`Triple`

.. rb:const:: HOST

  The host platform compiling on.

  :rtype: :rb:class:`Triple`
