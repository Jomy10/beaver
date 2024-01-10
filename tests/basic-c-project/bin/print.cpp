#include <print.h>
#include <iostream>
#include <stdlib.h>

extern "C" void print_greeting(struct Person* person) {
  char* txt = greet_text(person);
  std::cout << txt << std::endl;
  free(txt);
}

