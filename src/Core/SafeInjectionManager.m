#import "SafeInjectionManager.h"
#import "iOSVersionHelper.h"
#import "../AppViewController.h"

@implementation SafeInjectionManager

+ (instancetype)shared {
    static SafeInjectionManager *sharedInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedInstance = [[SafeInjectionManager alloc] init];
    });
    return sharedInstance;
}

- (void)waitForUIReadyThenExecute:(void(^)(void))block {
    if (!block) return;
    
    dispatch_async(dispatch_get_main_queue(), ^{
        if ([self isUIReady]) {
            block();
        } else {
            // Retry after delay
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                [self waitForUIReadyThenExecute:block];
            });
        }
    });
}

- (BOOL)isUIReady {
    UIWindow *keyWindow = [self getKeyWindow];
    if (!keyWindow) return NO;
    
    UIViewController *rootVC = keyWindow.rootViewController;
    return rootVC != nil;
}

- (UIWindow *)getKeyWindow {
    if (@available(iOS 13.0, *)) {
        for (UIWindowScene *scene in [UIApplication sharedApplication].connectedScenes) {
            if (scene.activationState == UISceneActivationStateForegroundActive) {
                for (UIWindow *window in scene.windows) {
                    if (window.isKeyWindow) {
                        return window;
                    }
                }
            }
        }
    }
    
    return [UIApplication sharedApplication].keyWindow;
}

- (void)injectUIIfNeeded {
    [self waitForUIReadyThenExecute:^{
        NSLog(@"DEBUG* [SafeInjectionManager] Injecting UI...");
        AppViewController *appVC = [[AppViewController alloc] init];
        [appVC renderImportApp:[UIApplication sharedApplication]];
    }];
}

@end
