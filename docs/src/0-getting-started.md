# Getting started

Beaver is a simple, capable build system and command runner.
It is a ruby library, meaning you get the benefits of having a complete language
at your fingertips when creating your build scripts.

## Installation

**recommended way**:
```sh
gem install beaver --source https://gem.jomy.dev -v "3.2.0"
```

Or through **github packages** (requires authentication):

```sh
gem install beaver --source "https://rubygems.pkg.github.com/jomy10"
```

Or **build from source**:
<!-- TODO: bundler -->
```sh
git clone https://github.com/jomy10/beaver
cd beaver
./build.sh build install
```

## Your first build script

To verify that everything is working, create a file `make.rb` and paste the
following in it:
```ruby
require 'beaver'

cmd :hello do
    puts "hello world"
end
```

Run the script using:
```sh
ruby make.rb hello
```

The output will be:
```sh
hello
```

## Next steps

To continue, look at next chapter where we will build a C project using
these commands, or skip to the managed C project chapters, which provide
an easier way to manage your C projects.

- [Using commands](1-using-commands-to-build-a-c-project.md)
- [Using the managed C project](2-using-project-to-build-a-c-project.md)


