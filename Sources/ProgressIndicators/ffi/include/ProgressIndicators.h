#include <stdbool.h>

enum Stream {
  STREAM_STDOUT = 0,
  STREAM_STDERR = 1,
};

typedef void ProgressIndicators;
typedef void ProgressBar;

const ProgressIndicators* _Nonnull indicators_start(enum Stream);

void indicators_stop(const ProgressIndicators* _Nonnull);

void indicators_tick(const ProgressIndicators* _Nonnull);

void indicators_println(const ProgressIndicators* _Nonnull, const char* _Nonnull);

const ProgressBar* _Nonnull indicators_register_spinner(
  const ProgressIndicators* _Nonnull,
  const char* _Nullable message,
  const char* _Nullable style_string,
  const char* _Nullable tick_chars,
  const char* _Nullable prefix
);

void progress_bar_set_message(const ProgressBar* _Nonnull, const char* _Nonnull message);

char* _Nonnull progress_bar_message(const ProgressBar* _Nonnull);

void progress_bar_finish(const ProgressBar* _Nonnull, const char* _Nullable);

void rs_cstring_destroy(char* _Nonnull);

// bool progress_is_color_enabled(const Progress* _Nonnull);

// const Progress* _Nonnull start_progress(enum Stream);

// void stop_progress(const Progress* _Nonnull);

// void tick_progress(const Progress* _Nonnull);

// /// Returns false if an error occurred
// bool progress_println(const Progress* _Nonnull, const char* _Nonnull message);


// ProgressBar* _Nonnull register_spinner(
//   const Progress* _Nonnull,
//   const char* _Nullable message,
//   const char* _Nullable style_string,
//   const char* _Nullable tick_char,
//   const char* _Nullable prefix
// );

// void finish_spinner(ProgressBar* _Nonnull spinner, const char* _Nullable message);

// void spinner_set_message(ProgressBar* _Nonnull spinner, const char* _Nullable message);
