#import <Foundation/Foundation.h>

@interface TweakManager : NSObject

@property (nonatomic, strong, readonly) NSDictionary *config;

+ (instancetype)shared;
- (void)initializeWithBundleID:(NSString *)bundleID;
- (BOOL)shouldEnableForBundle:(NSString *)bundleID;

@end
