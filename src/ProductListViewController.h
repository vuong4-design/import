#import "Foundation/Foundation.h"

#import "SharedLibraries/Product.h"

@interface ProductListViewController : UIViewController {
	NSArray<Product *> *_products;
	UIScrollView *_scrollView;
	UIStackView *_prodsStackView;
	UIStackView *_historyStackView;
	UIView *_contentView;
}

@property(retain, nonatomic, readwrite) NSArray<Product *> *products; //@synthesize products=_products
@property(retain, nonatomic) UIScrollView *scrollView; //@synthesize scrollView=_scrollView
@property(retain, nonatomic) UIStackView *prodsStackView; //@synthesize prodsStackView=_prodsStackView
@property(retain, nonatomic) UIStackView *historyStackView; //@synthesize historyStackView=_historyStackView

@property(retain, nonatomic) UIView *contentView; //@synthesize contentView=_contentView



@end
