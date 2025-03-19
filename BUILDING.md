# Building

```sh
cargo build --release
```

## Static linking to ruby

**Ruby needs to be installed as a static library**

*using ruby-build*
```sh
export RUBY_CONFIGURE_OPTS="--enable-static"
ruby-build -d 3.4.1 ~/.rubies
```

**Build the library with static-ruby feature enabled**

```sh
cargo build --release --features static-ruby
```
