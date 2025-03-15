#
# Example of defining options and arguments which can be passed to beaver and
# used inside of your build script + custom commands
#

# Define an option
# Optionas have values
#
# To use options and flags, they have to be passed after a `--` to
# differentiate them from beaver's own options
# Can be used like:
#   beaver -- --sdl-version 3
#   beaver -- -s 3
sdlVersion = opt "sdl-version", "s", default: 2

# Define a flag
# Flags have no value but represent a boolean. default is false
# Can be used like:
#   beaver -- --from-source
buildFromSource = flag "from-source"

# Flags can also be negated if the default value is true, or if
# the default option is nil
# Can be used like:
#   beaver -- --warn    # true
#   beaver -- --no-warn # false
#   beaver -- -w        # false
#   beaver           # nil
warnings = flag "warn", "w", default: nil

# Define a command
# Commands can be called from the command line just like the standard `run` or `test`.
#
# The first commmand defined is also the default command
#
# Can be used like:
#   beaver helloWorld
#   beaver
cmd "helloWorld" do
  puts "Hello world"
end

cmd "shellCommand" do
  sh "echo 'Hello world!'"
  sh "echo", "Hello world!"
end

cmd "printArg" do
  # Arguments can also be inside of cmds or if blocks, etc.
  # It will only take the argument if this block is executed
  argName = opt "argument-name", default: nil
  case argName
    when "sdl-version" then puts sdlVersion
    when "from-source" then puts buildFromSource
    when "warn" then puts warnings
    else puts "Unknown argument-name: #{argName}"
  end
end
