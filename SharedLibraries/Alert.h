#import "UIKit/UIKit.h"

@interface Alert : NSObject

+ (void)show:(void (^)(void))callback
       title:(NSString *)title
     message:(NSString *)message;

@end
