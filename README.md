# Beaver build tool

Beaver is an easy to understand build tool with a lot of capabilities.

- [How to use](#how-to-use)
- [Installation](#installation)

```ruby
requre 'beaver'

OUT="build/"

cmd :build, each("src/*.c") do
  sh %(clang #{$file} -c -o #{File.join(OUT, $file.name)}.o)
end

$beaver.end
```

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

cmd :hello do
  sh %(echo 'Hello world!')
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

If you want to make your life a little easier, you can use the beaver CLI that ships with beaver.
use `beaver init` to initialize the current directory to be a project using beaver. This will
create a beaver script file and will either create a `.gitignore`, or append to an existing one.

### File dependencies

Commands can depend on files. If any of those files were changed since the last run of the command,
the command will be run again, otherwise it is ignored.

#### `all`

Let's say we have a C project, it contains 2 source files called `src/main.c` and `src/util.c`.
We want to recompile our project if any of those files changed.

```ruby
#!/usr/bin/env ruby
require 'beaver'

cmd :build, all(["src/main.c", "src/util.c"]) do
  sh %(clang #{$files} -o build/a.out)
end

$beaver.end
```

The above `build` command will execute if any of the `src` files changed. The `$files` variable
will contain the files defined inside of `all`. When you print files, it will give you a
comma separated list of the files (e.g. `"src/main.c" "src/util.c"`).

This is a very simple example, but what if we added another source file, we don't want to add
another file to the list of sources. Instead, we can do `all("src/*.c")`. If we later on decide to
change the source directory to something else, it would be better to store "src" in a constant,
same goes for the build directory, or the c compiler. Let's add those as well.

```ruby
#!/usr/bin/env ruby
require 'beaver'

# Define constants
BUILD_DIR = "./build"
SRC_DIR = "./src"
CC = "clang"

cmd :build, all("#{SRC_DIR}/*.c") do
  sh %(#{CC} #{$files} -o #{File.join(BUILD_DIR, "a.out")})
end

$beaver.end
```

That's much better, and easier to maintain. `File.join` will take care of adding the file
separators for us. In this case it is equivalent to `"#{BUILD_DIR}/#{a.out}"`

#### `each`

When we replace `all` with `each` in the above examle, the command will no longer run
once with all files passed to a `$files` variable, instead the command will run for each
file in the list, and the file will be passed to the `$file` variable.

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

cmd :build do
  call :build_src_to_objects
  call :build_objects_to_exec
end

# Ran for each .c file in SRC_DIR
cmd :build_src_to_objects, each(File.join(SRC_DIR, "/**/*.c"))
  sh %(#{CC} #{$file} -c -o #{File.join(BUILD_DIR, "#{$file.name}.o")})
end

# Ran once for all .o files
cmd :build_objects_to_exec, all(File.join(BUILD_DIR, "**/*.o"))
  sh %(#{CC} #{$files} -o #{File.join(BUILD_DIR, "a.out")})
end

$beaver.end
```

Let's break down the above code. Our new main command combines the 2 commands below it using
`call`. This will execute the command you pass to it, taking into account the file dependencies.

Then, in *build_src_to_objects*, we run the body of our command  for each C source file and
compile it into an object file, which is put in the `BUILD_DIR`. `$file.name` is a method to
get the filename (e.g. `main.c` -> `main`). There are more of these [methods](lib/file_obj.rb).

Lastly, the *build_objects_to_exec* command will build the object files to an executable.

Now, let's say we want to only compile our object files. We can do this with `./make.rb build_src_to_objects`.

That's it. This is what Beaver offers. An added bonus is that you can use all of Ruby's capabilities
in your scripts, since Beaver is just a Ruby script that imports the Beaver library.
You can keep on reading for some more features.

## Options

You can `set`, `rm` and check if beaver `has` an option.

```ruby
$beaver.set(:e) # when set, the script will exit on errors
```

## Silent

When a shell command is called using `sh`, the command and its output are printed to the stdout.
You can override this behaviour.

For example, `sh %(echo "Hello world")` will output:
```
echo "Hello world"
Hello world
```

`sh silent %(echo "Hello world")` will output:
```
Hello world
```

and `sh full_silent %(echo "Hello world")` will output nothing.

## Clean

When you want to clean the beaver cache, you can do the following:

```ruby
require 'beaver'

cmd :clean do
  $beaver.clean # cleans the cache
end

$beaver.end
```

## Overrides

You can override where beaver stores its file info using `$beaver.cache_loc = "..."`

## More on the argument of a `sh` command

In all of the examples above, I have used the following:

```ruby
sh %(some_shell_command)
```

However, a regular string, or any string literal in ruby will work as well.


```ruby
sh "some_shell_command"
```

## Installation

For Beaver to work, you must install [Ruby](https://www.ruby-lang.org/en/).

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
