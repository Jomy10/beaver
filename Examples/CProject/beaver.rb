# Create a new project
Project(name: "MyProject")

# Create an executable target inside of project "MyProject"
C::Executable(
  # The name of the executable
  name: "HelloWorld",
  # A description of the target
  description: "Prints hello world to stdout",
  # The source file(s) to compile
  sources: "main.c"
)
