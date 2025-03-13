#include <stdio.h>

extern char* get_message();
extern void destroy_message(char*);

int main(void) {
  char* message = get_message();
  printf("%s\n", message);
  destroy_message(message);
}
