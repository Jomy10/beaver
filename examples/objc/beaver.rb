Project(name: "Obj-C_Project") # TODO: escape spaces

C::Executable(
  name: "hello_objc",
  language: :objc,
  sources: "main.m",
  headers: ".",
  dependencies: [framework("Foundation")]
)
