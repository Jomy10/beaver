#import <Foundation/Foundation.h>
#include <assert.h>
#import <class_def.h>

@implementation Greeter
  - (id)initWithName:(NSString*)name {
    self = [super init];
    if (self) {
      self->_message = [NSString stringWithFormat:@"%@ %@", @"Hello ", name];
    }
    return self;
  }
@end

int main(void) {
  Greeter* greeter = [[Greeter alloc] initWithName:@"Beaver"];
  NSString* message = [greeter message];

  NSLog(@"%@\n", message);

  assert([message isEqualTo:@"Hello Beaver"]);
}
