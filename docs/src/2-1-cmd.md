# cmd

We can define a command using `cmd`:

```ruby
cmd(
    # The name of the command. This name is unique and used to call it from the
    # command line
    name,
    # The input files 
    # Type: each(String | String[]) | all(String | String[])
    input = nil,
    # The output file(s)
    # Type: 
    #   if input is each
    #       Proc that takes a SingleFile struct
    #   if input is all
    #       String
    out: nil,
    # The project this command belongs to. When not specified this is either the
    # current project or nil of there is no project defined
    project: $beaver.current_project,
    # Run the command in parallel (only works for an Each dependency)
    parallel: false,
    # A block passed to the command that gets executed
    &fn
)
```

