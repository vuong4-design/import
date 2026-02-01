#import "ProductViewElementCreator.h"

@implementation ProductViewElementCreator

+ (UIStackView *)createRow {
	UIStackView *row = [[UIStackView alloc] init];
	row.axis = UILayoutConstraintAxisHorizontal;
	row.spacing = 20;
	row.distribution = UIStackViewDistributionEqualSpacing;
	row.translatesAutoresizingMaskIntoConstraints = NO;
	return row;
}

+ (UILabel *)createLabel:(NSString *)text {
	UILabel *label = [[UILabel alloc] init];
	label.translatesAutoresizingMaskIntoConstraints = NO;
	label.text = text;
	return label;
}

@end
