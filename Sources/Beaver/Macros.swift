@attached(extension, conformances: Project, names: arbitrary)
public macro ProjectWrapper() = #externalMacro(module: "UtilMacros", type: "EnumWrapper")

@attached(extension, conformances: CommandCapableProject, names: arbitrary)
public macro CommandCapableProjectWrapper(skipping: [String]?) = #externalMacro(module: "UtilMacros", type: "EnumWrapper")

@attached(extension, conformances: MutableProject, names: arbitrary)
public macro MutableProjectWrapper(skipping: [String]?) = #externalMacro(module: "UtilMacros", type: "EnumWrapper")

@attached(extension, conformances: TargetBase, names: arbitrary)
public macro TargetBaseWrapper() = #externalMacro(module: "UtilMacros", type: "EnumWrapper")

@attached(extension, conformances: Target, names: arbitrary)
public macro TargetWrapper() = #externalMacro(module: "UtilMacros", type: "EnumWrapper")

@attached(extension, conformances: Library, names: arbitrary)
public macro LibraryWrapper() = #externalMacro(module: "UtilMacros", type: "EnumWrapper")


@attached(extension, conformances: Project, names: arbitrary)
public macro ProjectPointerWrapper() = #externalMacro(module: "UtilMacros", type: "PointerWrapper")

@attached(extension, conformances: CommandCapableProject, names: arbitrary)
public macro CommandCapableProjectPointerWrapper() = #externalMacro(module: "UtilMacros", type: "PointerWrapper")

@attached(extension, conformances: MutableProject, names: arbitrary)
public macro MutableProjectPointerWrapper() = #externalMacro(module: "UtilMacros", type: "PointerWrapper")
