#include <stdio.h>
#include <MyMath.h>
#include <absl/log/check.h>

int main(void) {
  printf("%d\n", add(1, 2));
  CHECK(false);
}
