# Beaver build tool

Beaver is an easy to understand build tool with a lot of capabilities.

- [How to use](#how-to-use)
- [Installation](#installation)

## How to use

### Basics

Beaver is a ruby gem library, meaning that it can be imported in any ruby file.
To start, lets create a file called `make.rb` (can be named anything), containing the following:

```ruby
#!/usr/bin/env ruby
require 'beaver'

$beaver.end
```

This is a basic beaver file, but right now it won't do anything.
Beaver relies on **commands**, which have a name. Commands can be called from the command line.
Let's add a new command called `hello`.

```ruby
#!/usr/bin/env ruby
require 'beaver'

command :hello do
  system "echo 'Hello world!'"
end

$beaver.end
```

**NOTE**: When installing from RubyGems, you need to put `require 'beaver-build'` at the top of
your beaver scripts instead of `require 'beaver'`.

Run the above by either doing `ruby make.rb` or 
```bash
chmod +x make.rb
./make.rb
```

The last suggestion is the preferred way of executing a beaver script. When we execute our
script, we should see `Hello world!` in the console. 

The command that beaver executed was the first defined command, this is the main command.
We can also explicitly call it using `./make.rb hello`.

In the example above, we used the `system` function to call a shell command. We can also
use the alias `sys`, which will first print out the command passed in and then execute it.
This is the preferred way for things like C compilation commands, which are constructed in
the script.

If you want to make your life a little easier, you can use the beaver CLI that ships with beaver.
use `beaver init` to initialize the current directory to be a project using beaver. This will
create a beaver script file and will either create a `.gitignore`, or append to an existing one.

### Dependencies

#### Many files to one

Let's say we have a C project, it contains 2 source files called `src/main.c` and `src/util.c`.
We want to recompile our project if any of those files changed.

```ruby
#!/usr/bin/env ruby
require 'beaver'

command :build, src: ["src/main.c", "src/util.c"], target: "build/a.out" do |sources, target|
  system "mkdir -p #{target.dirname}" # Make the build directory if it doesn't exist
  sys "clang #{sources} -o #{target}"
end

$beaver.end
```

The above command will execute if any of the `src` files changed, and it will pass those files as
a space separated string to the command using the first argument after the `do` keyword (i.e. `sources`).
This means that the `sources` variable contains the string "src/main.c src/util.c". The `target`
variable will contain "build/a.out".

This is a very simple example, but what if we added another source file, we don't want to add
another file to the list of sources. Instead, we can do `src/*.c`. If we later on decide to
change the source directory to something else, it would be better to store "src" in a constant,
same goes for the build directory, or the c compiler. Let's add those as well.

```ruby
#!/usr/bin/env ruby
require 'beaver'

# Define constants
BUILD_DIR = "./build"
SRC_DIR = "./src"
CC = "clang"

command :build, src: "#{SRC_DIR}/*.c", target: "#{BUILD_DIR}/a.out" do |sources, target|
  system "mkdir -p #{target.dirname}" # Make the build directory if it doesn't exist
  sys "#{CC} #{sources} -o #{target}"
end

$beaver.end
```

That's much better, and easier to maintain. One note here is that instead of `"#{SRC_DIR}/*.c"`,
we could have also typed `File.join(SRC_DIR, "*.c")`. This will take care of file separators for us.

#### Many files to many files

Now, let's say our C project grows bigger and bigger. Recompiling all source files everytime one
of them changes might be a little overkill. So, why don't we compile every source file to an
object file first, and compile the object files into the executable program.

```ruby
#!/usr/bin/env ruby
require 'beaver'

# Define constants
BUILD_DIR = "./build"
SRC_DIR = "./src"
CC = "clang"

command :build do
  $beaver.call :build_src_to_objects
  $beaver.call :build_objects_to_exec
end

# Many files to many files
command :build_src_to_objects, src: "#{SRC_DIR}/**/*.c", target_dir: "#{BUILD_DIR}", target_ext: ".o" do |source, target|
  system "mkdir -p #{target.dirname}"
  sys "#{CC} #{source} -c -o #{target}"
end

# Many files to one
command :build_objects_to_exec, src: "#{BUILD_DIR}/**/*.o", target: "#{BUILD_DIR}/a.out" do |sources, target|
  system "mkdir -p #{target.dirname}" # Make the build directory if it doesn't exist
  sys "#{CC} #{sources} -o #{target}"
end

$beaver.end
```

Let's break down the above code. Our new main command combines the 2 commands below it using
`$beaver.call`. This will execute the command you pass to it. 

Then, in *build_src_to_objects*, we compile C files to object files. The source files are 
all C files located in our source directory. We want to compile them to our build directory, 
and they will have the `.o` extension. Next to the `do` keyword, we find `source`, 
which is a variable with only one source file this time. The `target` variable contains 
its corresponding object file (e.g. source would contain `src/util.c` and target would contain `build/src/util.o`). 
This command will be called for each C file that changed since the last time you ran the beaver script, 
passing in the changed C file location to the command.

Lastly, the *build_objects_to_exec* command will build the object files to an executable.
This is the same as the `build` command in our previous examples, but the source files are now
all object files in our build directory instead of our C files, and the `-o` flag is passed to
the compiler.


Now, let's say we want to only compile our object files. We can do this with `./make.rb build_src_to_objects`.

That's it. This is what Beaver offers. An added bonus is that you can use all of Ruby's capabilities
in your scripts, since Beaver is just a Ruby script that imports the Beaver library.

## Installation

### From GitHub Package Registry

```bash
gem install beaver --source "https://rubygems.pkg.github.com/jomy10"
```

[more info](https://github.com/Jomy10/beaver/packages/1597405).

### From RubyGems

```bash
gem install beaver-build
```

**NOTE**: When installing from RubyGems, you need to put `require 'beaver-build'` at the top of
your beaver scripts instead of `require 'beaver'`.

### Build from source

```bash
git clone https://github.com/jomy10/beaver
cd beaver
./build.sh build install
```

I advice building from source or downloading from the github registry for convenience.

## Tips

Want to put(s) some more color into your build scripts? Use the [`colorize`](https://rubygems.org/gems/colorize) gem
to give color to your print statemets. Example: `puts "Failed to compile".red`, `puts "Compilation finished".green`.

## Contributing

Feel free to open an issue regarding bugs or improvements. If you want to work on an improvement,
you can do so by commenting on its issue and opening a pull request. Your help is much appreciated!

To test out the library, use `./build.sh build install` to build and install it as a gem.
You can use `./build.sh uninstall` to remove the gem and `./build.sh clean` to clean the project
of gem files.

## Questions

Feel free to ask any questions you may have by opening an issue.

## License

This software is licensed under the [MIT](LICENSE) license.
