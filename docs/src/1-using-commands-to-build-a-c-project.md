# Using commands to build a C project

Let's get hands-on and learn the fundamentals by building a C project.

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

### Hello world

Let's start with a simple hello world, in `make.rb`:

```ruby
require 'beaver' # 1

cmd :hello do # 2
    puts "hello world" # 3
end
```

Let's break down what we did:

- (1): We imported to beaver library, we only have to do this in our main script
- (2): We created a new **command** with the name *hello*
- (3): In the body of this command, we call the puts function

We can now run this command as follows:
```sh
$ ruby make.rb hello
hello world
```

We just called the command "hello" from the command line.

The first command in our file is actually a special command, it is the *main* command.
This means that it gets called when no arguments are provided, thus the following is
also correct:

```sh
$ ruby make.rb
hello world
```

### Quality of life

We can make our script executable;

- Add this to the top of the script:
```ruby
#!/usr/bin/env ruby

cmd :build do
    
end
```

- Execute the following:
```sh
chmod +x make.rb
```

We can now call our script like this:
```sh
$ ./make.rb
hello world
```

### Compiling our C code

It's time to introduce the `sh` command, this will execute a shell command.
Modify `make.rb`:

```ruby
cmd :build do
    sh %(clang src/*.c -o main)
end
```

```sh
$ ./make.rb build
clang src/*.c -o main
$ ./main
Hello world
```

<!-- TODO: move to separate chapter? -->

### Caching with `each`

Since we don't want to recompile everything every time, we can compile our source
files into object files first and only recompile them if the source files changed.
To do this, use the `each` dependency:

```ruby
BUILD_DIR = "build"

cmd :build, each("src/*.c") out: proc { |f| File.join(BUILD_DIR, f.basename + ".o") } do |file, outfile|
    sh %(clang -c #{file} -o #{outfile})
end
```

Let's break it down:
- `each("src/*.c")`: We want to recompile the files `src/*.c` whenever they change
- `out: proc { |f| File.join(BUILD_DIR, f.basename + ".o") }`: We compile these files into the BUILD\_DIR/file.o, this lambda
  passed to the `out` parameter defines the output filename.
- `do |file, outfile|`: The block at the end now accepts 2 arguments: the input file
  and the output file.

Try to run the script now and you'll see it gets executed for each file. Run it
again and you'll see it won't compile anything anymore.

### Caching with `all`

The `all` dependency is similar to `each`, but the block is called only once with
all the input files, there is only one output file and the block is called when any
of the input files are changed.

To apply this to our C example, let's put all our object files together into an executable:

```ruby
BUID_DIR = "build"

cmd :build do
    call :build_objects
    call :link_objects
end

cmd :build_objects, each("src/*.c"), out: proc { |f| File.join(BUILD_DIR, f.basename + ".o") } do |file, outfile|
    sh %(clang -c #{file} -o #{outfile})
end

cmd :link_objects, all(File.join(BUILD_DIR, "*.o")), out: "main" do |files, outfile|
    sh %(clang #{files} -o #{outfile})
end
```

You'll notice:
- Inside of the :build command
    - `call :command_name`: this will call the command with the specified name
- In the :link_objects command
    - `all(...)`: this defines an `all` dependency as I previously stated
    - `out: "main"`: an `all` dependency only has 1 output file

Try running the script and see what happens now!

