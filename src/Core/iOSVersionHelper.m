#import "iOSVersionHelper.h"

@implementation iOSVersionHelper

+ (NSInteger)majorVersion {
    static NSInteger version = 0;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        version = [[NSProcessInfo processInfo] operatingSystemVersion].majorVersion;
    });
    return version;
}

+ (BOOL)isStoreKit2Available {
    if (@available(iOS 15.0, *)) {
        return YES;
    }
    return NO;
}

+ (BOOL)supportsAsyncStoreKit {
    if (@available(iOS 15.0, *)) {
        return YES;
    }
    return NO;
}

+ (CGRect)safeApplicationFrame {
    CGRect screenBounds = [[UIScreen mainScreen] bounds];
    UIEdgeInsets safeArea = UIEdgeInsetsZero;
    
    if (@available(iOS 11.0, *)) {
        UIWindow *keyWindow = nil;
        
        if (@available(iOS 13.0, *)) {
            for (UIWindowScene *scene in [UIApplication sharedApplication].connectedScenes) {
                if (scene.activationState == UISceneActivationStateForegroundActive) {
                    for (UIWindow *window in scene.windows) {
                        if (window.isKeyWindow) {
                            keyWindow = window;
                            break;
                        }
                    }
                }
                if (keyWindow) break;
            }
        }
        
        if (!keyWindow) {
            keyWindow = [UIApplication sharedApplication].keyWindow;
        }
        
        if (keyWindow) {
            safeArea = keyWindow.safeAreaInsets;
        }
    }
    
    CGRect frame = CGRectMake(
        safeArea.left, safeArea.top,
        screenBounds.size.width - safeArea.left - safeArea.right,
        screenBounds.size.height - safeArea.top - safeArea.bottom
    );
    
    return frame;
}

@end
