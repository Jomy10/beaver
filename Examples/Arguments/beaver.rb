#
# Example of defining options and arguments which can be passed to beaver and
# used inside of your build script
#

# Define an argument
# Arguments have values
# Can be used like:
#   beaver --sdl-version 3
#   beaver -s 3
sdlVersion = arg "sdl-version", "s", default: "2"

# Define an option
# Options have no value but represent a boolean. default is false
# Can be used like:
#   beaver --from-source
buildFromSource = opt "from-source"

# Options can also be negated if the default value is true, or if
# the default option is nil
# Can be used like:
#   beaver --warn    # true
#   beaver --no-warn # false
#   beaver -w        # false
#   beaver           # nil
warnings = opt "warn", "w", default: nil

# Define a command
# Commands can be called from the command line just like the standard `build`,
# `run` and `test`. When no project is defined, these standard commands can also
# be used for your custom commands
#
# The first commmand defined is also the default command
#
# Can be used like:
#   beaver build
#   beaver
cmd "helloWorld" do
  puts "Hello world"
end

# Overwrites
# When there is also a Project defined in this build script, but you want to use
# a custom "build" command, then `overwrite` is required.
#
# Can be used like:
#   beaver build
cmd "build", overwrite: true do
  puts "Building..."
  if fileChanged("main.c")
    puts "rebuilding main.c..."
  end
  sleep 4
  puts "Done."
end

cmd "shellCommand" do
  sh "echo 'Hello world!'"
  sh "echo", "Hello world!"
end
