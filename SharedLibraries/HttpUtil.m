#import "HttpUtil.h"

#ifndef API_HOST
#define API_HOST @""
#endif

static NSString *const kExportEndpointPath = @"/api/inventory/export";

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
	NSString *host = API_HOST;
	if (host.length == 0) {
		NSLog(@"DEBUG* export endpoint missing API_HOST");
		if (completion) {
			completion(0, nil);
		}
		return;
	}

	NSString *urlString = [NSString stringWithFormat:@"%@%@", host, kExportEndpointPath];
	NSURL *url = [NSURL URLWithString:urlString];
	if (!url) {
		NSLog(@"DEBUG* export endpoint invalid URL: %@", urlString);
		if (completion) {
			completion(0, nil);
		}
		return;
	}

	NSError *error = nil;
	NSData *body = [NSJSONSerialization dataWithJSONObject:params ?: @{} options:0 error:&error];
	if (error) {
		NSLog(@"DEBUG* export endpoint JSON error: %@", error.localizedDescription);
		if (completion) {
			completion(0, nil);
		}
		return;
	}

	NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
	request.HTTPMethod = @"POST";
	[request setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
	request.HTTPBody = body;

	NSURLSessionDataTask *task = [[NSURLSession sharedSession]
		dataTaskWithRequest:request
		completionHandler:^(NSData *data, NSURLResponse *response, NSError *requestError) {
			if (requestError) {
				NSLog(@"DEBUG* export endpoint request error: %@", requestError.localizedDescription);
				if (completion) {
					completion(0, nil);
				}
				return;
			}

			NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *)response;
			id parsed = nil;
			if (data.length > 0) {
				parsed = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
			}
			if (completion) {
				completion(httpResponse.statusCode, parsed);
			}
		}];
	[task resume];
}

- (void)checkInventoryForProduct:(NSString *)productID
                       completion:(void (^)(BOOL exists, NSDictionary *item))completion {
	(void)productID;
	if (completion) {
		completion(NO, nil);
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
