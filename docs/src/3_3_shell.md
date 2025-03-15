# Shell utilities

```ruby
sh "string or list of arguments"
```

```ruby
opt "name"
opt "name", "short_name", default: "optional default value"
opt "name", default: 3 # can be string, int, float, bool. this will automatically cast arguments passed by the user
```

```ruby
flag "name"
flag "name", "short_name", default: nil # nil or false -> enables `-no-[name]` option
```

```ruby
cmd "name" do
  # things to execute
end
```
