#import "ProductCollector.h"

@implementation ProductCollector

+ (instancetype)shared {
    static ProductCollector *instance;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        instance = [[ProductCollector alloc] init];
    });
    return instance;
}

- (void)wrapDelegate:(id<SKProductsRequestDelegate>)delegate forRequest:(SKProductsRequest *)request {
    // This method is intended to be used if we wanted to proxy the delegate
    // But since we are hooking SKProductsResponse directly in UniversalStoreKitHooks.xm,
    // we might not strictly need to proxy the delegate object itself if we can catch the response method.
    // However, keeping this for potential future advanced interception.
    // For now, it's a placeholder or log.
    NSLog(@"DEBUG* [ProductCollector] Delegate wrapper called for %@", NSStringFromClass([delegate class]));
}

- (void)collectProducts:(NSArray<SKProduct *> *)products {
    if (products.count == 0) return;
    
    NSString *bundleID = [[NSBundle mainBundle] bundleIdentifier];
    NSMutableArray *productData = [NSMutableArray array];
    
    for (SKProduct *product in products) {
        NSDictionary *info = @{
            @"product_id": product.productIdentifier ?: @"",
            @"product_name": product.localizedTitle ?: @"",
            @"price": product.price ?: @0,
            @"currency": [product.priceLocale objectForKey:NSLocaleCurrencyCode] ?: @"USD",
            @"description": product.localizedDescription ?: @""
        };
        [productData addObject:info];
        
        NSLog(@"DEBUG* [ProductCollector] Collected: %@ - %@", product.productIdentifier, product.localizedTitle);
    }
    
    // Create the payload structure
    NSDictionary *payload = @{
        @"bundle_id": bundleID,
        @"products": productData
    };
    
    // Check if HttpUtil supports collectProducts, if not we need to add it or generic post.
    // Assuming HttpUtil has a generic or we add a specific method.
    // Since HttpUtil is shared, we should ideally add `collectProducts` to it or use a generic selector.
    // For now, assuming we will add `collectProducts:completion:` to HttpUtil later or it exists dynamically.
    
    HttpUtil *httpUtil = [HttpUtil sharedInstance];
    if ([httpUtil respondsToSelector:@selector(collectProducts:completion:)]) {
         [httpUtil performSelector:@selector(collectProducts:completion:) 
                        withObject:payload 
                        withObject:^(BOOL success) {
            NSLog(@"DEBUG* [ProductCollector] Backend sync: %@", success ? @"success" : @"failed");
         }];
    } else {
         NSLog(@"DEBUG* [ProductCollector] HttpUtil does not implement collectProducts:completion:");
    }
}

- (void)productsRequest:(SKProductsRequest *)request didReceiveResponse:(SKProductsResponse *)response {
    // Collect products from response
    [self collectProducts:response.products];
}

@end
