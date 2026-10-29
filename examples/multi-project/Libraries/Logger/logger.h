#include <stdio.h>

typedef enum {
  TRACE,
  DBG,
  INFO,
  WARNING,
  ERROR,
} LogLevel;

void _log(LogLevel, FILE*, const char* fmt, ...);

#define FTRACE(f, ...) _log(TRACE, f, __VA_ARGS__)
#define FDEBUG(f, ...) _log(DBG, f, __VA_ARGS__)
#define FINFO(f, ...) _log(INFO, f, __VA_ARGS__)
#define FWARN(f, ...) _log(WARNING, f, __VA_ARGS__)
#define FERR(f, ...) _log(ERROR, __VA_ARGS__)

#define TRACE(...) FTRACE(stderr, __VA_ARGS__)
#define DBG(...) FDEBUG(stderr, __VA_ARGS__)
#define INFO(...) FINFO(stderr, __VA_ARGS__)
#define WARN(...) FWARN(stderr, __VA_ARGS__)
#define ERR(...) FERR(stderr, __VA_ARGS__)
