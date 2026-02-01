#import "StoreKit/StoreKit.h"

#import "SharedLibraries/HttpUtil.h"
#import "SharedLibraries/Product.h"
#import "SharedLibraries/Alert.h"

#import "Auth/AuthManager.h"
#import "AppViewController.h"
#import "AppTopViewController.h"
#import "ProductListViewController.h"
#import "AuthModel.h"
#import "ExportManager.h"
#import "ObserverManager.h"

@interface AppViewController ()<UIGestureRecognizerDelegate>
@end

@implementation AppViewController

- (void) viewDidLoad {
	[super viewDidLoad];

	// Initialize AppView here.
	UIView *appView = [
		[UIView alloc] initWithFrame:CGRectMake(
			0,
			0,
			[[UIScreen mainScreen] applicationFrame].size.width,
			[[UIScreen mainScreen] applicationFrame].size.height
		)
	];

	appView.userInteractionEnabled = YES;
	appView.backgroundColor = [UIColor whiteColor];

	// Initialize tap event
	UITapGestureRecognizer *singleFingerTap = [
		[UITapGestureRecognizer alloc]
			initWithTarget:self
							action:@selector(handleTap:)
	];

	[appView addGestureRecognizer:singleFingerTap];
	singleFingerTap.delegate = self;

	// Add tweakLabel to appView
	self.view = appView;

	// Add top bar view controller
	[self appTopViewController];

	[self setupModeToggle];

	[self productListViewController];

	// Listen to pay event to initialize inapp payment.
	[
		[NSNotificationCenter defaultCenter]
			addObserver:self
				 selector:@selector(inappPaymentObserver:)
						 name:@"notifyInappPayment"
					 object:nil
	];

	// Assign a payment observer so we can store item transaction info.
	self.vbStoreKitManager = [[VBStoreKitManager alloc] init];

	[[SKPaymentQueue defaultQueue] addTransactionObserver:self.vbStoreKitManager];

}

- (void) dealloc {
	self.appTopViewController = nil;
	self.productListViewController = nil;
}

- (AppTopViewController *)appTopViewController {
	if (!_appTopViewController) {
		_appTopViewController = [[AppTopViewController alloc] init];
		[self addChildViewController:_appTopViewController];
		[self.view addSubview:_appTopViewController.view];
	}
	return _appTopViewController;
}

- (ProductListViewController *)productListViewController {
	if (!_productListViewController) {
		_productListViewController = [[ProductListViewController alloc] init];
		[self addChildViewController:_productListViewController];
		[self.view addSubview:_productListViewController.view];
	}
	return _productListViewController;
}

- (void) renderImportApp:(UIApplication *)app {
	UIWindow *window = ([UIApplication sharedApplication].delegate).window ;

	// Override the app view.
	self.view.center = window.center;

	// Override the app controller.
	window.rootViewController = self;

	[window addSubview:self.view];
}

- (void)setupModeToggle {
	UISegmentedControl *modeControl = [[UISegmentedControl alloc]
		initWithItems:@[@"Import Mode", @"Export Mode"]];

	modeControl.selectedSegmentIndex = [ExportManager shared].exportMode ? 1 : 0;
	[modeControl addTarget:self
									action:@selector(modeChanged:)
					forControlEvents:UIControlEventValueChanged];

	modeControl.frame = CGRectMake(10, 45, 240, 30);
	[self.appTopViewController.view addSubview:modeControl];
}

- (void)modeChanged:(UISegmentedControl *)control {
	BOOL isExportMode = (control.selectedSegmentIndex == 1);
	[ExportManager shared].exportMode = isExportMode;

	if (isExportMode) {
		[
			Alert
				show:^(){
					NSLog(@"DEBUG* export mode enabled");
				}
				title: @"Export Mode"
				message: @"Items purchased will be saved to inventory, not added to game."
		];
	} else {
		[
			Alert
				show:^(){
					NSLog(@"DEBUG* import mode enabled");
				}
				title: @"Import Mode"
				message: @"Items will be delivered to the game as usual."
		];
	}
}

- (void)inappPaymentObserver:(NSNotification *)notification {
	if ([[notification name] isEqualToString:@"notifyInappPayment"]) {
		// Check if user has logged in to the system.
		AuthManager *authManager = [AuthManager sharedInstance];

		if (![authManager isLoggedIn]) {
			[
				Alert
					show:^(){
						NSLog(@"DEBUG* login before importing product");
					}
					title: @"[尚未登入]"
					message: @"登入後才能入庫喔"
			];

			return;
		}

		// Start inapp payment.
		NSDictionary *userInfo = notification.userInfo;
		NSString *nProdID = [userInfo objectForKey:@"prodID"];
		SKMutablePayment *payment =[[SKMutablePayment alloc] init];
		payment.productIdentifier = nProdID;
		[[SKPaymentQueue defaultQueue] addPayment:payment];
	}
}

//The event handling method
- (void)handleTap:(UITapGestureRecognizer *)recognizer {
	[self.appTopViewController dismissKeyboard];
}

- (void) didReceiveMemoryWarning {
	[super didReceiveMemoryWarning];
	if (self.isViewLoaded && self.view.window == nil) {
		[self.appTopViewController.view removeFromSuperview];
		[self.productListViewController.view removeFromSuperview];
		self.appTopViewController = nil;
		self.productListViewController = nil;
		[[ObserverManager sharedManager] clearObservers];
	}
}

@end
