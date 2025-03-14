#include <stdio.h>
#include <hello-swift-Swift.h>

void callback(const char* _Nonnull message) {
  printf("%s\n", message);
}

int main(void) {
  with_message(callback);
  return 0;
}
