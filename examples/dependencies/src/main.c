#include <my_math.h>
#include <assert.h>
#include <stdio.h>
#include <uuid.h>
#include <stdbool.h>

int main() {
  int res = add(1, 2);
  assert(res == 3);
  printf("1 + 2 = %i\n", res);

  bool n = (bool) uuid_is_null(UUID_NULL);
  assert(n);
  printf("uuid_is_null = %i\n", n);
}
