#import <Foundation/Foundation.h>
#import <StoreKit/StoreKit.h>
#import "../../SharedLibraries/HttpUtil.h"

@interface ProductCollector : NSObject <SKProductsRequestDelegate>

+ (instancetype)shared;
- (void)collectProducts:(NSArray<SKProduct *> *)products;
- (void)wrapDelegate:(id<SKProductsRequestDelegate>)delegate forRequest:(SKProductsRequest *)request;

@end
