# Command line arguments and commands

You can collect command line arguments from your build script.

## Options and flags

An option is an argument that contains a value, a flag is one that does not.
All options and flags that should be passed to the build script have to be passed
after a `--`. Everything before the `--` are arguments for beaver itself, everything
after it are options for your beaver script.

**example script**

```ruby
puts(opt "sdl-version", "s", default: 2)
puts(flag "debug")
```

**example output**

```sh
$ beaver
2
false
$ beaver -- --sdl-version 3
3
false
$ beaver -- -s 3 --debug
3
true
```

## Commands

Custom commands can be defined. These can then be called by running `beaver [command-names...]`.

**example**

```ruby
cmd "test" do
  # Do testing...
  if successful
    puts "Tests successful!"
  else
    puts "Tests unsuccessful!"
  end
end
```

```sh
$ beaver test
Tests successful!
```

## Sh

Beaver also provides a utility function which prints a shell command and also executes it.

**example**

```ruby
# these are equivalent
sh "echo 'hello'"
sh "echo", "hello"
```

## See also

- More info can be found in the [example for arguments on GitHub](https://github.com/Jomy10/beaver/blob/master/examples/arguments/beaver.rb)
