#include <logger.h>
#include <stdarg.h>
#include <stdio.h>
#include <stdbool.h>

void _log(LogLevel level, FILE* f, const char* fmt, ...) {
  va_list args;
  va_start(args, fmt);

  switch (level) {
    case TRACE: fprintf(f, "[TRACE] "); break;
    case DEBUG: fprintf(f, "[DEBUG] "); break;
    case INFO: fprintf(f, "[INFO] "); break;
    case WARNING: fprintf(f, "[WARN] "); break;
    case ERROR: fprintf(f, "[ERR] "); break;
  }

  bool isFmt = false;
  while (*fmt != '\0') {
    if (isFmt && *fmt == 'd') {
      int i = va_arg(args, int);
      fprintf(f, "%d", i);
      isFmt = false;
    } else if (isFmt && *fmt == 'c') {
      int c = va_arg(args, int);
      fprintf(f, "%c", c);
      isFmt = false;
    } else if (isFmt && *fmt == 'f') {
      double d = va_arg(args, double);
      fprintf(f, "%f", d);
      isFmt = false;
    } else if (*fmt == '%') {
      isFmt = true;
    } else {
      fputc(*fmt, f);
    }
    ++fmt;
  }
  fputc('\0', f);

  va_end(args);
}
