# Beaver

Capable build system and command runner for any project.

Projects can be built programmatically because configuration is written in Ruby.

It is an excellent replacement for make and cmake.

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

Building requires **ruby** to be installed. The ruby version linked to will be the one that is accessible
from the command line `ruby --version`.

```sh
cargo build -p beaver-cli
```

## Installing

TODO

## Documentation

Coming soon

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
