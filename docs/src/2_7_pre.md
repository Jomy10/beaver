# Pre-phase hooks

Work that only needs to be done before a build (like generating a file) should be
put in a "pre-phase hook".

**example**: generate a header before a build

```ruby
build_dir "build"

Project(name: "MyProject")

# Will be run before a build
pre "build" do
  Dir.mkdir("build/generated") unless Dir.exist?("build/generated")
  File.write("generated/generated.h", "#define VALUE 1")
end

# Delete the file again when cleaning
pre "clean" do
  File.delete("generated/generated.h")
end

C::Executable(
  name: "main",
  sources: "main.c",
  headers: "build/generated" # use the generated headers
)
```

## Possible values

The currently defined phases are:

- build
- run
- clean

**NOTE**: when running, the build hook will also be executed.
