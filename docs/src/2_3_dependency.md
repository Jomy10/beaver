# Dependencies

Targets can have dependencies on other targets. This means that the dependency will be built
first and linked to the target depending on it.

## Example

Here we define a library and an executable, the executable depends on the library.

```ruby
Project(name: "MyProject")

C::Library(
  name: "MyMathLibrary",
  sources: "math/**/*.c"
)

C::Executable(
  name: "main",
  sources: ["main.c"],
  dependencies: ["MyMathLibrary"]
)
```

When the target is defined in the same project, we can refer to the target by name
(i.e. `"MyMathLibrary"`).

## Dependencies in other projects

When the target is not defined in the same project, we need to qualify the name by
prepending it with the project name (i.e. `MyOtherProject:MyMathLibrary`). An example:

```ruby
Project(name: "MyOtherProject")

C::Library(
  name: "MyMathLibrary",
  sources: "math/**/*.c"
)

Project(name: "MyProject")

C::Executable(
  name: "main",
  sources: ["main.c"],
  dependencies: ["MyOtherProject:MyMathLibrary"]
)
```

## Tip: `beaver list`

In bigger projects, or when [importing projects from other build systems](2_5_importing.md),
it is not clear at a glance which projects are available, for this you can use `beaver list`
to list all projects and targets.

**example**: take our example above, the output will be:

```sh
$ beaver list
MyOtherProject
  MyMathLibrary
MyProject
  main
```

## Static/dynamic linking

To override the default linking behaviour of beaver, you can explicity specify
how to link.

```ruby
static("target_name") # link to target_name statically
dynamic("target_name") # link to target_name dynamically
```

On macOS, `framework("target_name")` is also avaiable.

## System libraries

To link to a library that can be found through pkg-config:

```ruby
pkgconfig("sdl2")
```

Beaver also provides `system_lib`. This will simple add `-llib_name` to the linker flags.

```ruby
system_lib("lib_name")
```
