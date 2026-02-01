#import <Foundation/Foundation.h>

@interface TweakManager : NSObject

+ (instancetype)sharedManager;
- (void)start;

@end
