#include <my_math.h>
#include <assert.h>
#include <stdio.h>

int main() {
  int res = add(1, 2);
  assert(res == 3);
  printf("1 + 2 = %i\n", res);
}
