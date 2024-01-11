# Using a project to build a C project

We are going to build a C project using a Beaver C project. We will be making
the same project as in the [previous chapter](./1-1-using-commands-to-build-a-c-project.md),
but instead of using commands, we will use a project.

<!-- toc -->

## Our project

Let's say we have the following working directory:

```
.
├── make.rb
└── src
    ├── greeter.c
    ├── greeter.h
    └── main.c
```

contents of `main.c`:
```c
#include <stdio.h>
#include "greeter.h"

int main(void) {
	printf("%s\n", greet_message());
}
```

contents of `greeter.h`:
```c
char* greet_message(void);
```

contents of `greeter.c`:
```c
char* greet_message(void) {
	return "Hello world";
}
```

## Our build script

### Setup

Let's create a new file called `make.rb` and include the beaver library:
```ruby
require 'beaver'
```

We can call our script like this:

```ruby
ruby make.rb
```

It will tell us we specified an invalid command.

#### Quality of life

To make it easier to call our script, we can make it executable:

- Add this to the top of the script:
```ruby
#!/usr/bin/env ruby
```

- Execute the following:
```sh
chmod +x make.rb
```

We can now call our script like this:
```sh
./make.rb
```

### Compiling our C code

Let's create a project. In our `make.rb` file:

```ruby
Project.new("MyProject", build_dir: "build")
```

We create a project called "MyProject" and defined a build directory.

We can now define a C executable:

```ruby
C::Executable.new(
    name: "myExec",
    sources: "src/*.c"
)
```

We can now build our executable using `./make.rb build myExec`.
The executable will be located in the `./build/myExec` directory.

Since this is an executable, we can also run it using `./make.rb run myExec`

### Creating a library

Let's extract greeter.c into a separate library.

The new project layout is:

```
.
├── lib
│   ├── greeter.c
│   └── include
│       └── greeter.h
├── make.rb
└── src
    └── main.c
```

in `main.c`, we change the following line:

```diff
- #include "greeter.h"
+ #include "greeter.h"
```

Our new build script:

```ruby
require 'beaver'

Project.new("MyProject", build_dir: "build")

C::Library.new(
    name: "myLibrary",
    sources: "lib/*.c",
    include: "lib/include"
)

C::Executable.new(
    name: "myExec",
    sources: "src/*.c",
    dependencies: ["myLibrary"]
)
```

We can now run our program again using:

```sh
./make.rb run myExec
```

This will build our library and the executable and then run it.

We can also build our library separately:

```sh
./make.rb build myLibrary
```

### Linking a system library

Let's link pthread and sdl2 to our executable. We can use this by:

1. Defining the libraries

```ruby
# A system library; will get linked using -lpthread
C::Library.system("pthread")

# A system library that supports pkg-config
C::Library.pkg_config("sdl2")
```

2. Linking the libraries to our main executable.

We can do this by declaring them as dependencies:

```ruby
C::Executable(
    name: "myExec",
    sources: "src/*.c",
    dependencies: ["myLibrary", "pthread", "sdl2"]
)
```

### Private include flags

A target's include flags are passed to the targets that depend on it. We can also
declare private include paths.


```ruby
C::Library(
    name: "MyLibrary",
    # -Iinclude will get passed to the dependants, -Isrc will not
    include: { private: "src", public: "include" },
    sources: ["src/a.c", "src/b.c"]
)
```

## Building a C++ project

Libraries and executables can also contain C++ code. This can be achieved by specifying the
language:

```ruby
C::Library.new(
    name: "CppLib",
    language: "C++"
    sources: "lib/**/*.cpp",
    include: "include"
)

C::Executable.new(
    name: "CExecutable",
    language: "C",
    sources: "src/**/*.c",
    dependencies: ["CppLib"]
)
```

Possible values for the `language` attribute are: "C", "C++", "Mixed", "Obj-C".
In "Mixed" mode, beaver will determine the compiler to use by the file extension.

## Library type

By default, beaver will compile a static and dynamic version of your library. This
can be changed by specifying the library type:

```ruby
C::Library.new(
    name: "MyLibrary",
    type: "static" # can also be an array; [:static, :dynamic]
    # ...
)
```

### Static vs dynamic dependencies

By default, clang/gcc will try to dynamically link libraries if there is a dynamic
libary available. To explicitly statically link a library, you can use the following
syntax:

```rb
C::Executable.new(
    name: "my_exec",
    dependencies: [static("MyStaticallyLinkedLibrary")]
)
```

Dependencies in the same project as the dependant target will automatically be statically linked.

### Final notes

We can still define commands like we did in the previous chapter and call them
in the same way.

