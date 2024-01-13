# Importing another project

You can easily import targets from another project.

For example, let's say we have a different project defined in the path `deps/other-project/make.rb`.
The make.rb file looks like this:

```ruby
require 'beaver'

Project.new("OtherProject")

C::Library.new(
    name: "TheOtherLibrary",
    # ...
)
```

To import it the project and use the library target as a dependency, we do the
following in our own project:

```ruby
require 'beaver'

# Import the make.rb file
require_relative 'deps/other-project/make.rb'

Project.new("MyProject")

C::Library.new(
    name: "MyLibrary",
    dependencies: [
        # Use the library target of the other project as a dependency
        "OtherProject/TheOtherLibrary"
    ]
)
```

And that's all it takes!

