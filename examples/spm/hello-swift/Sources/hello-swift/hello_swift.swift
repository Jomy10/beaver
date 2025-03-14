let names = [
  "Patrick",
  "Debby",
  "Steven",
  "Amy"
]

// TODO: same problem as with cargo -> dependencies

@_cdecl("with_message")
public func withMessage(_ callback: @convention(c) (UnsafePointer<CChar>) -> Void) {
  let name = names.randomElement()!
  let greeting = "Hello \(name)"
  callback(greeting)
}
