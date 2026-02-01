#import "Foundation/Foundation.h"

@interface Product : NSObject

@property (nonatomic, copy) NSString *prodName;
@property (nonatomic, copy) NSString *prodID;
@property (nonatomic, copy) NSString *inventoryID;
@property (nonatomic, strong) NSNumber *price;
@property (nonatomic, strong) NSNumber *quantity;

- (instancetype)initWithProdName:(NSString *)prodName
                          prodID:(NSString *)prodID
                      inventoryID:(NSString *)inventoryID
                           price:(NSNumber *)price
                        quantity:(NSNumber *)quantity;

@end
