#import "Foundation/Foundation.h"

@class SKPaymentTransaction;

typedef void (^ExportCompletion)(BOOL success);
typedef void (^InventoryCheckCompletion)(BOOL exists, NSDictionary *item);

@interface ExportManager : NSObject

@property (nonatomic) BOOL exportMode;

+ (instancetype)shared;
+ (BOOL)shouldExportTransaction:(SKPaymentTransaction *)transaction;

- (void)exportTransaction:(SKPaymentTransaction *)transaction completion:(ExportCompletion)completion;
- (void)checkInventoryForProduct:(NSString *)productID completion:(InventoryCheckCompletion)completion;
- (void)markItemAsImported:(NSString *)inventoryID completion:(ExportCompletion)completion;

@end
