#import "UIKit/UIKit.h"

@interface ProductViewElementCreator : NSObject

+ (UIStackView *)createRow;
+ (UILabel *)createLabel:(NSString *)text;

@end
