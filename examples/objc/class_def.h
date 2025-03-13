#import <Foundation/Foundation.h>

@interface Greeter : NSObject
  @property (readonly) NSString* message;

  - (id)initWithName: (NSString*)name;
@end
