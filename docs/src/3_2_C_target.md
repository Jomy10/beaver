# C Targets

```ruby
C::[Executable|Library](
  name: "The target's name",
  description: "A description of this target",
  homepage: "A link to the homepage of this target",
  version: "A version", # string | int | float
  license: "A license name", # e.g. "MIT"
  # Source files, can contain glob patterns (e.g. src/**/*.c)
  sources: ["source list"], # array | string
  # By default, CFlags will be added to any target depending on this one.
  # This behaviour can be tweaked by using a hash of the form:
  # { public: ["a cflag"], private: ["a cflag only used by this target"] }
  cflags: ["a c flag"], # array | string | hash
  # By default, header paths are added to the search path of dependent targets
  # This behaviour can be tweaked by using a hash of the form:
  # { public: ["a path visible to the dependent"], private: ["a path not visible to the dependent"] }
  headers: ["a path to a directory containing headers"], # array | string | hash
  linker_flags: ["a linker flag"], # array | string
  # Valid artifacts for a C::Library are:
  # - :staticlib
  # - :dynlib
  # - :pkgconf
  # - :framework
  # - :xcframework
  # Valid artifacts for a C::Executable are:
  # - :executable
  # - :app (for a native application on macOS)
  artifacts: [:artifact_name], # array | symbol | string
  dependencies: ["some dependency"]
)
```
