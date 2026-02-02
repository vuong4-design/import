#import "StoreKit/StoreKit.h"

#import "SharedLibraries/HttpUtil.h"

#import <objc/message.h>

#import "ExportManager.h"

@implementation ExportManager

static NSString *const kExportedTransactionsKey = @"import_exported_transactions";
static NSString *const kExportRateLimitKey = @"import_export_rate_limit";
static NSString *const kTransactionHistoryKey = @"import_transaction_history";
static NSTimeInterval const kExportRateLimitWindow = 2.0;
static NSUInteger const kHistoryLimit = 50;

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
	if (![ExportManager shared].exportMode) {
		return NO;
	}
	NSString *transactionID = transaction.transactionIdentifier;
	if (transactionID.length == 0) {
		return YES;
	}
	NSArray *exported = [[NSUserDefaults standardUserDefaults] arrayForKey:kExportedTransactionsKey];
	if ([exported containsObject:transactionID]) {
		NSLog(@"DEBUG* export skipped duplicate transaction %@", transactionID);
		return NO;
	}
	return YES;
}

- (void)exportTransaction:(SKPaymentTransaction *)transaction completion:(ExportCompletion)completion {
	if (!transaction) {
		if (completion) {
			completion(NO);
		}
		return;
	}

	if (![self allowExportForTransaction:transaction]) {
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
			NSString *productID = transaction.payment.productIdentifier ?: @"";
			NSString *transactionID = transaction.transactionIdentifier ?: @"";
			NSString *status = (code == 200) ? @"exported" : @"failed";
			[self recordHistoryWithType:@"export"
											 productID:productID
										transactionID:transactionID
												 status:status];
			[self recordExportedTransaction:transaction success:(code == 200)];
			if (completion) {
				completion(code == 200);
			}
		};

		void (*msgSend)(id, SEL, NSDictionary *, void (^)(NSInteger, id)) = (void (*)(id, SEL, NSDictionary *, void (^)(NSInteger, id)))objc_msgSend;
		msgSend(httpUtil, exportSelector, params, exportBlock);
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
						BOOL success = (error == nil && [(NSHTTPURLResponse *)response statusCode] == 200);
						NSString *productID = transaction.payment.productIdentifier ?: @"";
						NSString *transactionID = transaction.transactionIdentifier ?: @"";
						NSString *status = success ? @"exported" : @"failed";
						[self recordHistoryWithType:@"export"
													 productID:productID
												transactionID:transactionID
														 status:status];
						[self recordExportedTransaction:transaction success:success];
						if (completion) {
							completion(success);
						}
				}
	];
}

- (BOOL)allowExportForTransaction:(SKPaymentTransaction *)transaction {
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	NSTimeInterval now = [NSDate timeIntervalSinceReferenceDate];
	NSTimeInterval last = [defaults doubleForKey:kExportRateLimitKey];
	if (last > 0 && (now - last) < kExportRateLimitWindow) {
		NSLog(@"DEBUG* export rate limited");
		return NO;
	}
	[defaults setDouble:now forKey:kExportRateLimitKey];

	NSString *transactionID = transaction.transactionIdentifier;
	if (transactionID.length == 0) {
		return YES;
	}
	NSArray *exported = [defaults arrayForKey:kExportedTransactionsKey];
	if ([exported containsObject:transactionID]) {
		NSLog(@"DEBUG* export duplicate detected %@", transactionID);
		return NO;
	}
	return YES;
}

- (void)recordExportedTransaction:(SKPaymentTransaction *)transaction success:(BOOL)success {
	if (!success) {
		return;
	}
	NSString *transactionID = transaction.transactionIdentifier;
	if (transactionID.length == 0) {
		return;
	}
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	NSArray *existing = [defaults arrayForKey:kExportedTransactionsKey] ?: @[];
	if ([existing containsObject:transactionID]) {
		return;
	}
	NSMutableArray *updated = [existing mutableCopy];
	[updated addObject:transactionID];
	[defaults setObject:updated forKey:kExportedTransactionsKey];
	[defaults synchronize];
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

		void (*msgSend)(id, SEL, NSString *, InventoryCheckCompletion) = (void (*)(id, SEL, NSString *, InventoryCheckCompletion))objc_msgSend;
		msgSend(httpUtil, checkSelector, productID, checkBlock);
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
			NSString *status = success ? @"imported" : @"failed";
			[self recordHistoryWithType:@"import"
											 productID:@""
										transactionID:inventoryID ?: @""
												 status:status];
			if (completion) {
				completion(success);
			}
		};

		void (*msgSend)(id, SEL, NSString *, ExportCompletion) = (void (*)(id, SEL, NSString *, ExportCompletion))objc_msgSend;
		msgSend(httpUtil, markSelector, inventoryID, markBlock);
		return;
	}

	if (completion) {
		completion(NO);
	}
}

- (NSArray<NSDictionary *> *)transactionHistory {
	NSArray *history = [[NSUserDefaults standardUserDefaults] arrayForKey:kTransactionHistoryKey];
	if (![history isKindOfClass:[NSArray class]]) {
		return @[];
	}
	return history;
}

- (void)recordHistoryWithType:(NSString *)type
									 productID:(NSString *)productID
								transactionID:(NSString *)transactionID
											 status:(NSString *)status {
	NSMutableDictionary *entry = [[NSMutableDictionary alloc] init];
	entry[@"type"] = type ?: @"";
	entry[@"productID"] = productID ?: @"";
	entry[@"transactionID"] = transactionID ?: @"";
	entry[@"status"] = status ?: @"";
	entry[@"timestamp"] = @([NSDate date].timeIntervalSince1970);

	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	NSArray *existing = [defaults arrayForKey:kTransactionHistoryKey] ?: @[];
	NSMutableArray *updated = [existing mutableCopy];
	[updated insertObject:entry atIndex:0];
	if (updated.count > kHistoryLimit) {
		[updated removeObjectsInRange:NSMakeRange(kHistoryLimit, updated.count - kHistoryLimit)];
	}
	[defaults setObject:updated forKey:kTransactionHistoryKey];
	[defaults synchronize];

	dispatch_async(dispatch_get_main_queue(), ^{
		[
			[NSNotificationCenter defaultCenter]
				postNotificationName:@"notifyTransactionHistoryUpdated"
											object:self
		];
	});
}

- (void)clearCachedData {
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	[defaults removeObjectForKey:kExportedTransactionsKey];
	[defaults removeObjectForKey:kTransactionHistoryKey];
	[defaults synchronize];
	dispatch_async(dispatch_get_main_queue(), ^{
		[
			[NSNotificationCenter defaultCenter]
				postNotificationName:@"notifyTransactionHistoryUpdated"
											object:self
		];
	});
}

@end
