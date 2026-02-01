#import "Product.h"

@implementation Product

- (instancetype)initWithProdName:(NSString *)prodName
                          prodID:(NSString *)prodID
                      inventoryID:(NSString *)inventoryID
                           price:(NSNumber *)price
                        quantity:(NSNumber *)quantity {
	self = [super init];
	if (self) {
		self.prodName = prodName;
		self.prodID = prodID;
		self.inventoryID = inventoryID;
		self.price = price;
		self.quantity = quantity;
	}
	return self;
}

@end
