#include <stdio.h>
#include <MyMath.h>
#include <uuid.h>

int main(void) {
  printf("%d\n", add(1, 2));
  printf("%d\n", uuid_is_null(UUID_NULL));
}
