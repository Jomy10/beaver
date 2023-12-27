# Beaver

Simple but capable build system and command runner for any project.

Beaver is a ruby library, which means your build scripts have the power of an
entire language at your fingertips.

It is an excellent replacement for make/cmake.

## As a make replacement

```ruby
OUT="out"
env CC, "clang"

cmd :build do
    call :build_objects
    call :create_library
end

cmd :build_objects, each("src/*.c"), out: proc { |f| File.join(OUT, f.path + ".o") } do |file, outfile|
    sh "#{CC} -c #{file} $(pkg-config sdl2 --cflags) -o #{outfile}"
end

cmd :create_library, all(File.join(OUT, "*.o")), out: "my_exec" do |files, outfile|
    sh "#{CC} #{files} $(pkg-config sdl2 --libs) -o #{outfile}"
end
```

## As a cmake replacement

```ruby
Project.new("MyProject", build_dir: "out")

C::Library.new(
    name: "MyLibrary",
    sources: ["lib/*.c"]
)

C::Library.pkg_config("SDL2")

C::Executable.new(
    name: "my_exec",
    sources: "src/*.c",
    dependencies: ["MyLibrary", "SDL2"]
)
```

## Installation

```sh
gem install beaver --source "https://rubygems.pkg.github.com/jomy10"
```

Or **build from source**:

```sh
git clone https://github.com/jomy10/beaver
cd beaver
./build.sh build install
```

## Documentation

In the [docs](./docs) directory, upload comes later.

## Contributing

Feel free to open an issue regarding bugs or improvements. If you want to work
on an improvement, you can do so by commenting on its issue and opening a pull
request. Your help is much appreciated!

Adding project management for other languages than C is also welcome.

To test out the libary, use `./build.sh build install` to build and install it a
gem. You can use `./build.sh uninstall` to remove the gem and `./build.sh clean`
to clean the project.

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
    I picked ruby as I find it an excellent choice for build scrpts. It comes
    wth a rich standard library for working with files and has a magical syntax.

Sure, it's "slow", but the compiler is usually the bottleneck anyway in build scripts.
</details>

## License

This software is licensed under the [MIT](LICENSE) license.

