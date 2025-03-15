# Importing projects

## Importing beaver projects

Importing another beaver project can be done by simple requiring it:

```ruby
require_relative "path/to/other/project/beaver.rb"

Project(name: "MyProject")

# ...
```

## Importing projects from other build systems

Projects from other build systems can be imported into beaver. This is done with
the function `import_{build-system-name}`.

Currently supported build systems:
- CMake: `import_cmake [path-to-project]`
- Cargo: `import_cargo [path-to-project]`
- Swift Package Manager: `import_spm [path-to-project]`

**example**
```ruby
import_cmake "./flatbuffers"

Project(name: "MyProject")

C::Executable(
  name: "uses_flatbuffers",
  language: :cpp,
  sources: "src/**/*.cpp",
  dependencies: ["FlatBuffers:flatbuffers"],
  cflags: ["-std=c++11"]
)
```

```sh
$ beaver list
FlatBuffers
  flatbuffers
  flatc
  flatsamplebfbs
  flatsamplebinary
  flatsampletext
  flattests
MyProject
  uses_flatbuffers
```

## Importing remote projects

**Unimplemented**

In the future beaver will be able to manage dependencies from remote hosts,
automatically downloading the right version, etc.
