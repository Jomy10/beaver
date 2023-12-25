# env

Define a constant that gets initialized from an environment variable

```
env(
    # The environment variable's name
    name,
    default_value,
    &transform
)
```

For example:

```ruby
env :CC, "clang"
```

Would be the equivalent of doing:

```ruby
CC = ENV["CC"] || "clang"
```

