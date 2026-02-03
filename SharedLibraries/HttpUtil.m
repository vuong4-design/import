#import "HttpUtil.h"

@implementation HttpUtil

+ (instancetype)sharedInstance {
	static HttpUtil *sharedInstance = nil;
	static dispatch_once_t onceToken;

	dispatch_once(&onceToken, ^{
		sharedInstance = [[HttpUtil alloc] init];
	});

	return sharedInstance;
}

- (void)login:(NSString *)username
     password:(NSString *)password
completedHandler:(void (^)(NSData *data, NSURLResponse *response, NSError *error))handler {
	(void)username;
	(void)password;
	if (handler) {
		handler([NSData data], [[NSURLResponse alloc] init], nil);
	}
}

- (void)fetchInventory:(NSString *)bundleID
     completedHandler:(void (^)(NSData *data, NSURLResponse *response, NSError *error))handler {
	(void)bundleID;
	if (handler) {
		handler([NSData data], [[NSURLResponse alloc] init], nil);
	}
}

- (void)addItemToInventory:(NSString *)productID
             transactionID:(NSString *)transactionID
                   receipt:(NSString *)receipt
           transactionTime:(NSDate *)transactionTime
          completedHandler:(void (^)(NSData *data, NSURLResponse *response, NSError *error))handler {
	(void)productID;
	(void)transactionID;
	(void)receipt;
	(void)transactionTime;
	if (handler) {
		handler([NSData data], [[NSURLResponse alloc] init], nil);
	}
}

- (void)exportItemToInventory:(NSDictionary *)params
                   completion:(void (^)(NSInteger code, id data))completion {
	(void)params;
	if (completion) {
		completion(200, @{});
	}
}

- (void)checkInventoryForProduct:(NSString *)productID
                       completion:(void (^)(BOOL exists, NSDictionary *item))completion {
	(void)productID;
	if (completion) {
		completion(NO, nil);
	}
}

- (void)collectProducts:(NSDictionary *)payload
             completion:(void (^)(BOOL success))completion {
    // Stub implementation - replace with actual network call
    // Endpoint: /api/products/collect
    NSLog(@"DEBUG* [HttpUtil] Collecting products: %@", payload);
    if (completion) {
        completion(YES);
    }
}

- (void)markItemAsImported:(NSString *)inventoryID
                completion:(void (^)(BOOL success))completion {
	(void)inventoryID;
	if (completion) {
		completion(YES);
	}
}

@end
