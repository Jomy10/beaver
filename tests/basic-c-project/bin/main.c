#include <print.h>
#include <greeter.h>
#include <stdio.h>

#ifdef TEST_COMPILE_ERROR
// private includes of dependencies should not accessible
#include <person.h>
#endif

int main(void) {
  struct Person person;
  person.name = "John Doe";
  print_greeting(&person);
  #ifdef MY_LIB_PRIV
  printf("ERROR\n");
  #endif
  #ifdef MY_LIB_PUB
  printf("GOOD\n");
  #endif
  return 0;
}

