# Defining a target

Once a [project](2_1_project.md) is defined, targets can be added to it.

There are 2 kinds of targets: libraries and executables.

To define a library written in C:

```ruby
Project(name: "MyProject")

C::Library(
  name: "MyLibrary",
  sources: "src/**/*.c"
)
```

To define an executable, you'd write `C::Executable` instead.

## C Targets

### Language

C targets also allow compiling C++, Objective-C and Objective-C++. To do this, you
specify a language:

```ruby
C::Library(
  name: "MyLibrary",
  language: :cxx, # specify language
  sources: "src/**/*.c"
)
```

### Headers

A library can contain headers that a dependent target should be able to use. For this,
define the `headers` field

```ruby
C::Library(
  name: "MyLibrary",
  sources: "src/**/*.c", # string or array
  headers: "path/to/headers/directory" # string or array
)
```

Private headers (i.e. header paths that are included for the target defining them, but not
by any dependent targets) can also be defined.

```ruby
C::Library(
  name: "MyLibrary",
  sources: ["src/**/*.c"],
  headers: {
    public: "path/to/headers/public",
    private: "path/to/headers/private",
  }
)
```

## Building a target

- To build all targets, simple run `beaver`.
- To build a specific target, use `beaver [target-name]` (e.g. `beaver MyLibrary`).

## Running an executable

An executable can be run using `beaver run [executable-name]`.

## See also

- [C targets API-documentation](3_2_C_target.md)
