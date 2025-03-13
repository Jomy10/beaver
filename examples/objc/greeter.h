#import <Foundation/Foundation.h>
// also works (-fmodules automatically passed as cflag): @import Foundation;

@interface Greeter : NSObject
  @property (readonly) NSString* message;

  - (id)initWithName: (NSString*)name;
@end
