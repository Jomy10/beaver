# Defining a project

To start, create a `beaver.rb` script file in the root of your repository.

In order to define [targets](2_2_target.md), you need to define a project in which
these targets will reside.

To create a beaver project:

```ruby
Project(name: "MyProject")
```

All paths will be resolved based on the project's base directory, by default this is
the current directory. To set another base directory, you can use the `base_dir` argument.

```ruby
Project(name: "MyProject", base_dir: "./MyProject")
```
