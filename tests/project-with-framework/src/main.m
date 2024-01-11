#include <Foundation/Foundation.h>

int main(void) {
  NSString* str = [NSString stringWithUTF8String: "Hello world"];
  NSLog(@"%@\n", str);
}

