#include <logger.h>
#include <cxxvec.h>
#include <stdio.h>
#include <assert.h>
#include <string.h>

int main(void) {
  char buffer[1000];
  FILE* f = fmemopen(buffer, sizeof(buffer), "w");

  FINFO(f, "Hello world");

  int cmp = strcmp(buffer, "[INFO] Hello world");
  printf("cmp = %d\n", cmp);
  printf("buffer = %s\n", buffer);
  assert(cmp == 0);

  void* vec = new_vec();

  vec_push(vec, 1);
  vec_push(vec, 4);

  int val = vec_get(vec, 1);

  assert(val == 4);

  vec_destroy(vec);

  fclose(f);
}
