@_exported import CPlatform

public struct Platform {
  // OS //
  public static let macOS = PLATFORM_MAC == 1
  public static let linux = PLATFORM_LINUX == 1
  public static let minGW = PLATFORM_WINDOWS_MINGW == 1

  public static let pathSeparator = PATH_SEPARATOR

  // Extensions //
  public static let dynlibExtension = DYNLIB_EXTENSION
  public static let executableExtension = EXECUTABLE_EXTENSION
}
