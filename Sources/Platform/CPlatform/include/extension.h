#if PLATFORM_WINDOWS
  #define DYNLIB_EXTENSION ".dll"
  #define EXECUTABLE_EXTENSION ".exe"
#elif PLATFORM_APPLE
  #define DYNLIB_EXTENSION ".dylib"
  #define EXECUTABLE_EXTENSION ""
#else
  #define DYNLIB_EXTENSION ".so"
  #define EXECUTABLE_EXTENSION ""
#endif
