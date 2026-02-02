#import <Foundation/Foundation.h>

#import "NetworkFallbackHooks.h"

static BOOL IsReceiptVerificationRequest(NSURLRequest *request) {
	if (!request) {
		return NO;
	}
	NSURL *url = request.URL;
	if (!url) {
		return NO;
	}
	NSString *host = url.host.lowercaseString;
	if (![host isKindOfClass:[NSString class]]) {
		return NO;
	}
	if (![host containsString:@"buy.itunes.apple.com"]) {
		return NO;
	}
	NSString *path = url.path ?: @"";
	return [path containsString:@"verifyReceipt"];
}

static void LogReceiptResponse(NSData *data) {
	if (!data) {
		return;
	}
	NSError *error = nil;
	NSDictionary *payload = [NSJSONSerialization JSONObjectWithData:data options:0 error:&error];
	if (error || ![payload isKindOfClass:[NSDictionary class]]) {
		NSLog(@"DEBUG* receipt validation response parse failed: %@", error.localizedDescription);
		return;
	}
	NSDictionary *receipt = payload[@"receipt"];
	NSArray *inApps = receipt[@"in_app"];
	if ([inApps isKindOfClass:[NSArray class]] && inApps.count > 0) {
		NSDictionary *latest = [inApps lastObject];
		NSString *productID = latest[@"product_id"] ?: @"(unknown)";
		NSString *transactionID = latest[@"transaction_id"] ?: @"(unknown)";
		NSLog(@"DEBUG* receipt validation captured product %@ transaction %@", productID, transactionID);
	} else {
		NSLog(@"DEBUG* receipt validation response without in_app transactions");
	}
}

%group NetworkFallbackHooks

%hook NSURLSession

- (NSURLSessionDataTask *)dataTaskWithRequest:(NSURLRequest *)request
				 completionHandler:(void (^)(NSData *data, NSURLResponse *response, NSError *error))completionHandler {
	if (!IsReceiptVerificationRequest(request) || !completionHandler) {
		return %orig(request, completionHandler);
	}

	void (^wrappedHandler)(NSData *, NSURLResponse *, NSError *) = ^(NSData *data, NSURLResponse *response, NSError *error) {
		if (!error) {
			LogReceiptResponse(data);
		}
		completionHandler(data, response, error);
	};

	return %orig(request, wrappedHandler);
}

%end

%end

void InitNetworkFallbackHooks(void) {
	NSLog(@"DEBUG* network fallback hooks initialized");
	%init(NetworkFallbackHooks);
}
