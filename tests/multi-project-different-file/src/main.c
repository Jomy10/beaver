#include <stdio.h>

extern char* greet_message(void);

int main(void) {
  printf("%s\n", greet_message());
}

