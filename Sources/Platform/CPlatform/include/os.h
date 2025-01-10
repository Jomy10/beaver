// see: http://web.archive.org/web/20191012035921/http://nadeausoftware.com/articles/2012/01/c_c_tip_how_use_compiler_predefined_macros_detect_operating_system

#if defined(__unix__) || (defined(__APPLE__) && defined(__MACH__))
#include <sys/param.h>
#endif

#define PLATFORM_LINUX 0
#define PLATFORM_ANDROID 0
#define PLATFORM_CYGWIN 0
#define PLATFORM_WINDOWS 0
#define PLATFORM_WINDOWS64 0
#define PLATFORM_WINDOWS32 0
#define PLATFORM_WINDOWS_CYGWIN 0
#define PLATFORM_WINDOWS_MINGW 0
#define PLATFORM_WINDOWS_PHONE 0
#define PLATFORM_APPLE 0
#define PLATFORM_IPHONE_SIM 0
#define PLATFORM_IPHONE 0
#define PLATFORM_MAC 0
#define PLATFORM_EMSCRIPTEN 0
#define PLATFORM_BSD 0
#define PLATFORM_FREEBSD 0
#define PLATFORM_DRAGONFLY_BSD 0
#define PLATFORM_NETBSD 0
#define PLATFORM_OPENBSD 0
#define PLATFORM_AIX 0
#define PLATFORM_HPUX 0
#define PLATFORM_SOLARIS 0

#define PLATFORM_UNIX 0
#define PLATFORM_POSIX 0
#define PLATFORM_MACH 0

// Operating Systems //

#if defined(__linux__)
  #undef PLATFORM_LINUX
  #define PLATFORM_LINUX 1
  #if defined(__ANDROID__)
    #undef PLATFORM_ANDROID
    #define PLATFORM_ANDROID 1
  #endif
#elif defined(__CYGWIN__) && !defined(_WIN32)
  // POSIX development environment for Windows (32-bit)
  #undef PLATFORM_CYGWIN
  #define PLATFORM_CYGWIN 1
#elif defined(_WIN32)
  #undef PLATFORM_WINDOWS
  #define PLATFORM_WINDOWS 1
  #if defined(_WIN64)
    #undef PLATFORM_WINDOWS64
    #define PLATFORM_WINDOWS64 1
  #else
    #undef PLATFORM_WINDOWS32
    #define PLATFORM_WINDOWS32 1
  #endif
  #if defined(__CYGWIN__)
    #undef PLATFORM_WINDOWS_CYGWIN
    #define PLATFORM_WINDOWS_CYGWIN 1
  #elif defined (__MINGW32__)
    #undef PLATFORM_WINDOWS_MINGW
    #define PLATFORM_WINDOWS_MINGW 1
  #endif
  #if defined(WINAPI_FAMILY)
    #include <winapifamily.h>
    #if WINAPI_FAMILY_PARTITION(WINAPI_PARTITION_PHONE_APP)
      #undef PLATFORM_WINDOWS_PHONE
      #define PLATFORM_WINDOWS_PHONE 1
    #endif
  #endif
#elif defined(__APPLE__) && defined(__MACH__)
  #undef PLATFORM_APPLE
  #define PLATFORM_APPLE 1
  #include <TargetConditionals.h>
  #if TARGET_IPHONE_SIMULATOR == 1
    #unef PLATFORM_IPHONE_SIM
    #define PLATFORM_IPHONE_SIM 1
  #elif TARGET_OS_IPHONE == 1
    #undef PLATFORM_IPHONE
    #define PLATFORM_IPHONE 1
  #elif TARGET_OS_MAC == 1
    #undef PLATFORM_MAC
    #define PLATFORM_MAC 1
  #else
    #error "Undefined apple platform (please fix in `os.h`)"
  #endif
#elif defined(__EMSCRIPTEN__)
  #undef PLATFORM_EMSCRIPTEN
  #define PLATFORM_EMSCRIPTEN 1
#elif defined(BSD)
  #undef PLATFORM_BSD
  #define PLATFORM_BSD 1
  #if defined(__FreeBSD__)
    #undef PLATFROM_FREEBSD
    #define PLATFORM_FREEBSD 1
  #elif defined(__DragonFly__)
    #undef PLATFROM_DRAGONFLY_BSD
    #define PLATFORM_DRAGONFLY_BSD 1
  #elif defined(__NetBSD__)
    #undef PLATFORM_NETBSD
    #define PLATFORM_NETBSD 1
  #elif defined(__OpenBSD__)
    #undef PLATFORM_OPENBSD
    #define PLATFORM_OPENBSD 1
  #elif defined(__unix__) // Darwin OS'es also define BSD macro in sys/param.h, but not __unix__
    #error "Unknown BSD platform (please fix in `os.h`)"
  #endif
#elif defined(_AIX)
  #undef PLATFORM_AIX
  #define PLATFORM_AIX 1
#elif defined(__hpux)
  #undef PLATFROM_HPUX
  #define PLATFORM_HPUX 1
#elif defined(__sun) && defined(__SVR4)
  #undef PLATFORM_SOLARIS
  #define PLATFORM_SOLARIS 1
#else
  #error "Undefined operating system (please fix in `os.h`)"
#endif

// Standards //

#if !defined(_WIN32) && (defined(__unix__) || defined(__unix) || (defined(__APPLE__) && defined(__MACH__)))
  #undef PLATFORM_UNIX
  #define PLATFORM_UNIX 1
  #include <unistd.h>
  #if defined(_POSIX_VERSION)
    #undef PLATFORM_POSIX
    #define PLATFORM_POSIX 1
  #endif
#endif

#if defined(__MACH__)
  #undef PLATFORM_MACH
  #define PLATFORM_MACH 1 // Darwin, iOS, NextStep or other platform derived from the MACH kernel
#endif
