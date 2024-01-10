#include <person.h>
#include <greet.h>
#include <stdio.h>
#include <stdlib.h>

char* greet_text(struct Person* hello) {
  char* out = malloc(128 * sizeof(char));
  snprintf(out, 128, "Hello %s!", get_person_name(hello));
  return out;
}

