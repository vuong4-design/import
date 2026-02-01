#import "Storekit/Storekit.h"

#import "VBStoreKitManager.h"

#import "SharedLibraries/HttpUtil.h"
#import "SharedLibraries/Alert.h"
#import "ExportManager.h"

@interface SKPaymentQueue()
@property (nonatomic, copy) NSArray* transactions;
@end

@implementation VBStoreKitManager

// TODO
//   1. Intercept transaction receipt and transaction ID. The above 2 data should be send to BE.
//   2. Should we invoke "finishTransaction"? Will this effect the result to item delivery?
//			- If we don't invoke "finishTransaction" method, We can not proceed to next purchase. It seems like
//			  we need to invoke this method.
- (void)paymentQueue:(SKPaymentQueue *)queue updatedTransactions:(NSArray *)transactions {
    for (SKPaymentTransaction *transaction in transactions) {
        switch (transaction.transactionState) {
            case SKPaymentTransactionStatePurchased: {
										// Observe SKPaymentTransaction:
              NSLog(@"DEBUG* transaction success");

							if ([ExportManager shouldExportTransaction:transaction]) {
								[[ExportManager shared] exportTransaction:transaction completion:^(BOOL success) {
									if (success) {
										[[SKPaymentQueue defaultQueue] finishTransaction: transaction];
										[
											Alert
												show:^(){
													NSLog(@"DEBUG* export completed");
												}
												title: @"Exported"
												message: @"Item saved to inventory. Import later to use."
										];
									}
								}];

								break;
							}

							[self importTransactionFromBackend:transaction];

							break;
						}

            case SKPaymentTransactionStateFailed: {
                NSLog(@"DEBUG* VBStoreKitManager Transaction Failed");
                // [[SKPaymentQueue defaultQueue]
                //      finishTransaction:transaction];
                break;
						}

            default: {
							break;
						}
        }
    }
}

- (void)importTransactionFromBackend:(SKPaymentTransaction *)transaction {
	[[ExportManager shared] checkInventoryForProduct:transaction.payment.productIdentifier completion:^(BOOL exists, NSDictionary *item) {
		if (exists && item[@"inventoryID"]) {
			[[ExportManager shared] markItemAsImported:item[@"inventoryID"] completion:^(BOOL success) {
				if (success) {
					[[SKPaymentQueue defaultQueue] finishTransaction: transaction];
					[
						Alert
							show:^(){
								NSLog(@"DEBUG* import completed from inventory");
							}
							title: @"Imported"
							message: @"Item added to game from inventory."
					];

					[
						[NSNotificationCenter defaultCenter]
							postNotificationName:@"notifyRefreshProducts"
														object:self
					];
				}
			}];

			return;
		}

		NSURL *receiptURL = [[NSBundle mainBundle] appStoreReceiptURL];
		NSData *receipt = [NSData dataWithContentsOfURL:receiptURL];
		if (!receipt) {
			NSLog(@"DEBUG* VBStoreKitManager no receipt");
			return;
		}

		NSString *encodedReceipt = [receipt base64EncodedStringWithOptions:0];
		NSString *productID = transaction.payment.productIdentifier;
		HttpUtil *httpUtil = [HttpUtil sharedInstance];

		[
			httpUtil
				addItemToInventory:productID
						 transactionID:transaction.transactionIdentifier
									 receipt:encodedReceipt
					 transactionTime:transaction.transactionDate
					completedHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
						if (error) {
							[
								Alert show:^(){
									NSLog(@"failed to add game item to inventory %@", [error localizedDescription]);
								}
								title: @"Error"
								message: [error localizedDescription]
							];

							return;
						}

						NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *)response;
						NSError *parseError = nil;
						NSDictionary *responseDictionary = [
							NSJSONSerialization
								JSONObjectWithData:data
								options:0
								error:&parseError
						];

						if (parseError) {
							[
								Alert show:^(){
									NSLog(@"failed to add game item to inventory %@", [
											parseError localizedDescription
									]);
								}
								title: @"Error"
								message: [parseError localizedDescription]
							];

							return;
						}

						if (httpResponse.statusCode == 200) {
							[[SKPaymentQueue defaultQueue] finishTransaction: transaction];

							[
								Alert
									show:^(){
										// Dispatch event to "ProductListViewController" to rerender product list
										NSLog(@"DEBUG* import completed");
									}
									title: @"Success"
									message: @"import complete"
							];

							[
								[NSNotificationCenter defaultCenter]
									postNotificationName:@"notifyRefreshProducts"
																object:self
							];

						} else {
							[
								Alert
									show:^(){
										NSLog(@"DEBUG* item import failed");
									}
									title: @"Error"
									message: responseDictionary[@"err"]
							];
						}
					}
		];
	}];
}


@end

