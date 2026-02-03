#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

@interface iOSVersionHelper : NSObject

+ (NSInteger)majorVersion;
+ (BOOL)isStoreKit2Available;    // iOS 15+
+ (BOOL)supportsAsyncStoreKit;   // iOS 15.0+
+ (CGRect)safeApplicationFrame;  // Handle deprecated APIs

@end
