#import "Alert.h"

@implementation Alert

+ (void)show:(void (^)(void))callback
       title:(NSString *)title
     message:(NSString *)message {
	(void)title;
	(void)message;
	if (callback) {
		callback();
	}
}

@end
