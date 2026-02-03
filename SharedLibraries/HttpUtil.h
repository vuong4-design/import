#import "Foundation/Foundation.h"

@interface HttpUtil : NSObject

+ (instancetype)sharedInstance;

- (void)login:(NSString *)username
     password:(NSString *)password
completedHandler:(void (^)(NSData *data, NSURLResponse *response, NSError *error))handler;

- (void)fetchInventory:(NSString *)bundleID
     completedHandler:(void (^)(NSData *data, NSURLResponse *response, NSError *error))handler;

- (void)addItemToInventory:(NSString *)productID
             transactionID:(NSString *)transactionID
                   receipt:(NSString *)receipt
           transactionTime:(NSDate *)transactionTime
          completedHandler:(void (^)(NSData *data, NSURLResponse *response, NSError *error))handler;

- (void)exportItemToInventory:(NSDictionary *)params
                   completion:(void (^)(NSInteger code, id data))completion;

- (void)checkInventoryForProduct:(NSString *)productID
                       completion:(void (^)(BOOL exists, NSDictionary *item))completion;

- (void)collectProducts:(NSDictionary *)payload
             completion:(void (^)(BOOL success))completion;

- (void)markItemAsImported:(NSString *)inventoryID
                completion:(void (^)(BOOL success))completion;

@end
