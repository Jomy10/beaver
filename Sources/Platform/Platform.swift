@_exported import CPlatform

public struct Platform {
  public let macOS = PLATFORM_MAC == 1
  public let linux = PLATFORM_LINUX == 1
  public let minGW = PLATFORM_WINDOWS_MINGW == 1
}
