#include <stdio.h>

extern char* test_swift();

int main(void) {
  printf("%s\n", test_swift());
  return 0;
}

