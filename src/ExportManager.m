#import "StoreKit/StoreKit.h"

#import "SharedLibraries/HttpUtil.h"

#import "ExportManager.h"

@implementation ExportManager

+ (instancetype)shared {
	static ExportManager *sharedInstance = nil;
	static dispatch_once_t onceToken;

	dispatch_once(&onceToken, ^{
		sharedInstance = [[ExportManager alloc] init];
		sharedInstance.exportMode = NO;
	});

	return sharedInstance;
}

+ (BOOL)shouldExportTransaction:(SKPaymentTransaction *)transaction {
	(void)transaction;
	return [ExportManager shared].exportMode;
}

- (void)exportTransaction:(SKPaymentTransaction *)transaction completion:(ExportCompletion)completion {
	if (!transaction) {
		if (completion) {
			completion(NO);
		}
		return;
	}

	NSURL *receiptURL = [[NSBundle mainBundle] appStoreReceiptURL];
	NSData *receiptData = [NSData dataWithContentsOfURL:receiptURL];
	NSString *receiptString = receiptData ? [receiptData base64EncodedStringWithOptions:0] : nil;

	HttpUtil *httpUtil = [HttpUtil sharedInstance];
	SEL exportSelector = NSSelectorFromString(@"exportItemToInventory:completion:");

	if (receiptString && [httpUtil respondsToSelector:exportSelector]) {
		NSDictionary *params = @{
			@"productID": transaction.payment.productIdentifier ?: @"",
			@"transactionID": transaction.transactionIdentifier ?: @"",
			@"receipt": receiptString,
			@"transactionDate": @([transaction.transactionDate timeIntervalSince1970]),
			@"action": @"export"
		};

		void (^exportBlock)(NSInteger code, id data) = ^(NSInteger code, id data) {
			(void)data;
			if (completion) {
				completion(code == 200);
			}
		};

		[httpUtil performSelector:exportSelector withObject:params withObject:exportBlock];
		return;
	}

	if (!receiptString) {
		if (completion) {
			completion(NO);
		}
		return;
	}

	[
		httpUtil
			addItemToInventory:transaction.payment.productIdentifier
				 transactionID:transaction.transactionIdentifier
							 receipt:receiptString
				 transactionTime:transaction.transactionDate
				completedHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
					(void)data;
					if (completion) {
						completion(error == nil && [(NSHTTPURLResponse *)response statusCode] == 200);
					}
				}
	];
}

- (void)checkInventoryForProduct:(NSString *)productID completion:(InventoryCheckCompletion)completion {
	HttpUtil *httpUtil = [HttpUtil sharedInstance];
	SEL checkSelector = NSSelectorFromString(@"checkInventoryForProduct:completion:");

	if ([httpUtil respondsToSelector:checkSelector]) {
		void (^checkBlock)(BOOL exists, NSDictionary *item) = ^(BOOL exists, NSDictionary *item) {
			if (completion) {
				completion(exists, item);
			}
		};

		[httpUtil performSelector:checkSelector withObject:productID withObject:checkBlock];
		return;
	}

	if (completion) {
		completion(NO, nil);
	}
}

- (void)markItemAsImported:(NSString *)inventoryID completion:(ExportCompletion)completion {
	HttpUtil *httpUtil = [HttpUtil sharedInstance];
	SEL markSelector = NSSelectorFromString(@"markItemAsImported:completion:");

	if ([httpUtil respondsToSelector:markSelector]) {
		void (^markBlock)(BOOL success) = ^(BOOL success) {
			if (completion) {
				completion(success);
			}
		};

		[httpUtil performSelector:markSelector withObject:inventoryID withObject:markBlock];
		return;
	}

	if (completion) {
		completion(NO);
	}
}

@end
