#include <Foundation/Foundation.h>

int main(void) {
  NSAutoreleasePool* pool = [[NSAutoreleasePool alloc] init];
  NSString* str = [NSString stringWithUTF8String: "Hello world"];
  NSLog(@"%@\n", str);
  [pool drain];
  return 0;
}

