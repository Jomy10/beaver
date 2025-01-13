@attached(extension, conformances: Cli, names: arbitrary)
@attached(member, names: arbitrary)
public macro Cli() = #externalMacro(module: "CLIMacros", type: "CLIMacro")
