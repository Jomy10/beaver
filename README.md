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

cmd :build_objects, each("src/*.c"), out: proc { |f| File.join(OUT, f + ".o") } do |file, outfile|
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

C::Executable.new(
    name: "my_exec",
    sources: "src/*.c",
    dependencies: ["MyLibrary", "SDL2"]
)
```

