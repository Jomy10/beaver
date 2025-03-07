build_dir "build"

# Define a new project
Project(name: "MyProject")

# Add an executable to the project
C::Executable(
  name: "HelloWorld",
  sources: "src/main.c"
)
