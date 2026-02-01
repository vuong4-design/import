#import <Foundation/Foundation.h>

@class SKPaymentTransactionObserver;

@interface ObserverManager : NSObject

+ (instancetype)sharedManager;
- (void)trackObserver:(id)observer;
- (NSArray<NSDictionary *> *)trackedObservers;

@end
