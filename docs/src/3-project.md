# Project

A Project hosts [targets](./3-1-target.md).

```ruby
Project.new(
    # String
    name,
    # String
    build_dir: "out",
    # A block to define options using optparse
    &options
)
```

**Example of defining options**:

```ruby
Project.new("MyProject") do |opt|
    opt.on("--option", "Does stuff")
end

$beaver.postpone do
    puts $beaver.options[:option]
end
```

