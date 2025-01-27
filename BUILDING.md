# Building

**Clone the repo**
```sh
git clone https://github.com/Jomy10/beaver
git submodule update --init deps
```

**Configure and build**
```sh
ruby configure.rb
ruby build.rb release
```

You can also select a ruby version, for example: `ruby configure.rb 3.4`

For more options: `ruby configure.rb help`

## Requirements

- Swift compiler
- C compiler
- Rust compiler
- Ruby installed as a dynamic library (e.g. using `ruby-build`: `ruby-build -d 3.4.1 ~/.rubies`)
