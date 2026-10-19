# Beaver

[![docs](https://gh-stamps.vercel.app/api/docs?fontSize=14&borderRadius=10&borderWidth=1&padding=10&backgroundColor=9f6118&color=ffcda0&borderColor=e98d22&icon=book-medical&fontWeight=bold)](https://docs.beaver.jomy.dev)
[![download](https://gh-stamps.vercel.app/api/v4.3.0?fontSize=14&borderRadius=10&borderWidth=1&padding=10&backgroundColor=9f6118&color=ffcda0&borderColor=e98d22&icon=download&fontWeight=bold)](https://codeberg.org/Jomy10/beaver/releases/tag/4.3.0)

Capable build system and command runner for any project.

Projects can be built programmatically because configuration is written in Ruby.

It is an excellent replacement for make and cmake. Beaver also integrates with
other build systems so you can have dependencies that use other build systems.

## Example

```ruby
Project(name: "Game")

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
    system_lib("pthread")
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

Building requires **ruby** to be installed. The ruby version linked to will be the one that is accessible
from the command line `ruby --version`. A specific ruby can be chosen with the `RUBY` environment variable.

```sh
cargo build -p beaver-cli
```

## Installing

**from source**
```sh
cargo +nightly install --git https://github.com/jomy10/beaver
```

## Documentation

Documentation can be found on [docs.beaver.jomy.dev](https://docs.beaver.jomy.dev) and there examples in the [examples](examples) directory.

## Contributing

Feel free to open an issue regarding bugs or improvements. If you want to work
on an improvement, you can do so by commenting on its issue and opening a pull
request. Your help is much appreciated!

### Running tests

Be sure to check your changes with tests. Add new ones if your change is not coverd by the current tests.

```sh
cargo test
```

## Questions

Feel free to ask any questions you may have by opening an issue.

## License

This software is licensed under the [MIT](LICENSE) license.

## References

- ["Correct, Efficiant and Tailored: The Future of Build Systems" by Guillaume Maudoux and Kim Mens, Université catholique de Louvain, Journal of Software Engineering.](https://dial.uclouvain.be/pr/boreal/object/boreal%3A189586/datastream/PDF_01/view)
- ["Build System Rules and Algorithms" by Mike Shal, 2009.](https://gittup.org/tup/build_system_rules_and_algorithms.pdf)
