#import <Foundation/Foundation.h>

@class SKPaymentTransactionObserver;

@interface ObserverManager : NSObject

+ (instancetype)sharedManager;
- (void)registerObserver:(id)observer priority:(NSInteger)priority;
- (void)routeUpdatedTransactions:(NSArray *)transactions queue:(id)queue;
- (NSArray<NSDictionary *> *)trackedObservers;
- (BOOL)isRoutingObserver:(id)observer;
- (id)routingObserver;

@end
