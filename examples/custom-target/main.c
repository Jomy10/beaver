#include <assert.h>
#include <stdio.h>
#include <stdlib.h>

extern int test(void);

int main(void) {
  assert(test() == 1);

  #ifndef HAVE_SOME_LIB
  printf("Macro should be defined\n");
  exit(1);
  #endif

  return 0;
}
