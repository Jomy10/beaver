# Beaver

Simple but capable build system and command runner for any project.

Projects can be built programmatically because configuration is written in Ruby.

It is an excellent replacement for make and cmake.

## Example

```ruby
Project("Game")

C::Library(
  name: "Physics",
  description: "Physics simulation library",
  language: :cpp,
  sources: "lib/physics/*.cpp",
  include: "include/physics"
)

C::Library(
  name: "Renderer",
  language: :c,
  sources: "lib/renderer/*.c",
  include: "include/renderer",
  dependencies: [
    pkgconfig("SDL2"),
    system("pthread")
  ]
)

C::Executable(
  name: "Game",
  language: :cpp,
  sources: "src/*.cpp",
  dependencies: ["Physics", "Renderer"]
)
```

## Building

This project uses a simple ruby script `build.rb`, which forms a layer on top
of the swift build system.

For information on building this project, see [BUILDING.md](./BUILDING.md).

## Installing

After configuring which ruby version to use as outlined in [Building](./BUILDING.md),
run `ruby build.rb install release`.

<!-- ## As a cmake replacement

```ruby
Project("MyProject", buildDir: "out")

C::Library(
    name: "MyLibrary",
    sources: ["lib/*.c"],
    include: "include"
)

C::Executable(
    name: "my_exec",
    sources: "src/*.c",
    dependencies: ["MyLibrary", pkgconfig("SDL2")]
)
```

## As a make replacement

> [!warning] Currently unimplemented

```ruby
OUT="out"
env :CC, "clang"

cmd :build do
    call :build_objects
    call :create_executable
end

cmd :build_objects, each("src/*.c"), out: proc { |f| File.join(OUT, f.path + ".o") } do |file, outfile|
    sh "#{CC} -c #{file} $(pkg-config sdl2 --cflags) -o #{outfile}"
end

cmd :create_executable, all(File.join(OUT, "*.o")), out: "my_exec" do |files, outfile|
    sh "#{CC} #{files} $(pkg-config sdl2 --libs) -o #{outfile}"
end
```
 -->
## Documentation

Coming soon

<!-- In the [docs](./docs) directory, upload comes later. -->

## Contributing

Feel free to open an issue regarding bugs or improvements. If you want to work
on an improvement, you can do so by commenting on its issue and opening a pull
request. Your help is much appreciated!

<!-- To test out the libary, use `ruby build.rb install` to build and install it a
gem. You can use `./build.sh uninstall` to remove the gem and `./build.sh clean`
to clean the project. -->

### Running tests

<!-- [![Test macOS](https://github.com/Jomy10/beaver/actions/workflows/test-macos.yml/badge.svg)](https://github.com/Jomy10/beaver/actions/workflows/test-macos.yml)
[![Test Linux](https://github.com/Jomy10/beaver/actions/workflows/test-linux.yml/badge.svg)](https://github.com/Jomy10/beaver/actions/workflows/test-linux.yml)
[![Test Windows](https://github.com/Jomy10/beaver/actions/workflows/test-windows.yml/badge.svg)](https://github.com/Jomy10/beaver/actions/workflows/test-windows.yml)
 -->
Be sure to check your changes with tests. Add new ones if your change is not coverd by the current tests.

```ruby
ruby build.rb test
```

## Questions

Feel free to ask any questions you may have by opening an issue.

## FAQ

<details>
    <summary><b>Why choose Beaver over make?</b></summary>
    This project started as a more readable make replacement. I was
    getting frustrated by unreadable build tools. Beaver comes with
    all the features you'd expect from a make replacement.
</details>

<details>
    <summary><b>Why choose Beaver over cmake?</b></summary>
    Beaver takes an approach to project management that does not abstract
    away all knowledge of the clang/gcc compilers. It's easier to use and
    understand what's going on.
</details>

<details>
    <summary><b>Why Ruby?</b></summary>
    I picked ruby as I find it an excellent choice for build scripts. It comes
    wth a rich standard library for working with files and has a magical syntax.
</details>

## License

This software is licensed under the [MIT](LICENSE) license.
