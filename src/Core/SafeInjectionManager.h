#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

@interface SafeInjectionManager : NSObject

+ (instancetype)shared;
- (void)waitForUIReadyThenExecute:(void(^)(void))block;
- (void)injectUIIfNeeded;

@end
