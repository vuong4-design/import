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

@interface AppViewController ()<UIGestureRecognizerDelegate>
@end

#import "Core/iOSVersionHelper.h"

@implementation AppViewController

- (void) viewDidLoad {
	[super viewDidLoad];

	// Initialize AppView here.
    CGRect frame = [iOSVersionHelper safeApplicationFrame];
	UIView *appView = [[UIView alloc] initWithFrame:frame];

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
	self.appTopViewController = [[AppTopViewController alloc] init];
	[self addChildViewController: self.appTopViewController];
	[self.view addSubview: self.appTopViewController.view];

	[self setupModeToggle];

	self.productListViewController = [[ProductListViewController alloc]	init];
	[self addChildViewController: self.productListViewController];
	[self.view addSubview: self.productListViewController.view];

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

- (void) renderImportApp:(UIApplication *)app {
    UIWindow *window = [iOSVersionHelper safeApplicationFrame] ? nil : ([UIApplication sharedApplication].delegate).window;
    if (!window) {
        // Find key window safely
        if (@available(iOS 13.0, *)) {
            for (UIWindowScene *scene in [UIApplication sharedApplication].connectedScenes) {
                if (scene.activationState == UISceneActivationStateForegroundActive) {
                    for (UIWindow *w in scene.windows) {
                        if (w.isKeyWindow) { window = w; break; }
                    }
                }
            }
        }
        if (!window) window = [UIApplication sharedApplication].keyWindow;
    }

    if (!window) return;

    // Create a container view for our tweak UI that sits on top
    // Start with just a small button or minimized view
    CGFloat buttonSize = 50.0;
    UIButton *floatingButton = [UIButton buttonWithType:UIButtonTypeSystem];
    floatingButton.frame = CGRectMake(20, 100, buttonSize, buttonSize);
    floatingButton.backgroundColor = [UIColor systemBlueColor];
    floatingButton.layer.cornerRadius = buttonSize / 2;
    [floatingButton setTitle:@"🛠" forState:UIControlStateNormal];
    [floatingButton addTarget:self action:@selector(toggleMenu) forControlEvents:UIControlEventTouchUpInside];
    
    // Add pan gesture to move button
    UIPanGestureRecognizer *pan = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handlePan:)];
    [floatingButton addGestureRecognizer:pan];
    
    [window addSubview:floatingButton];
    
    // Configure main view to be hidden initially or overlay
    self.view.frame = CGRectMake(0, 0, window.bounds.size.width, window.bounds.size.height);
    self.view.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.0]; // Transparent initially
    self.view.hidden = YES; // Hidden by default
    
    // Add close button to self.view if not present in AppTopViewController
    
    [window addSubview:self.view];
    [window bringSubviewToFront:floatingButton];
    
    // Store reference to button if needed (using associated object or property if added)
    // For specific requirement "menu overlay occupying full screen", we fixed it by making it toggleable via floating button
}

- (void)handlePan:(UIPanGestureRecognizer *)recognizer {
    UIView *view = recognizer.view;
    CGPoint translation = [recognizer translationInView:view.superview];
    view.center = CGPointMake(view.center.x + translation.x, view.center.y + translation.y);
    [recognizer setTranslation:CGPointZero inView:view.superview];
}

- (void)toggleMenu {
    self.view.hidden = !self.view.hidden;
    if (!self.view.hidden) {
        self.view.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.8]; // Dim background when active
        [[self.view superview] bringSubviewToFront:self.view];
    }
}

- (void)setupModeToggle {
	UISegmentedControl *modeControl = [[UISegmentedControl alloc]
		initWithItems:@[@"Import Mode", @"Export Mode"]];

	modeControl.selectedSegmentIndex = 0;
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
}

@end
