build_dir "build"

import_spm "./hello-swift"

Project(name: "TestSwift")

C::Executable(
  name: "uses-swift",
  language: :objc,
  sources: ["main.m"],
  # {`name` in Package.swift}:{Product name}
  dependencies: ["hello-swift:hello-swift"]
)
