#include <stdio.h>
#include <assert.h>
#include <source.h>

int main(void) {
  assert(test() == 3);
  printf("Test passed\n");
  return 0;
}
