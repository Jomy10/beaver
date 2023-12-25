# each

```ruby
each(
    # String | String[]
    files
)
```

When specifying an each dependency, the `out:` parameter of `cmd` takes
a Proc that accepts a SingleFile struct. The first argument of the command
block is also of this type.

```ruby
{{#include ../../lib/files/file_obj.rb:2:22}}
```

