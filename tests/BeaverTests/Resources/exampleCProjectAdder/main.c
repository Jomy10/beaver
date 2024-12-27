#include <adder.h>
#include <assert.h>
#include <stdio.h>

int main() {
  struct Adder adder = (struct Adder) { 1, 2 };
  assert(add(&adder) == 3);

  printf("AdderTest passed\n");
}
