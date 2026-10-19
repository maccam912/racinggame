#import <CoreFoundation/CoreFoundation.h>
#import <LocalAuthentication/LocalAuthentication.h>

extern "C" CFTypeRef pacific_no_ui_auth_context() {
    @autoreleasepool {
        LAContext *context = [LAContext new];
        context.interactionNotAllowed = YES;
        return CFBridgingRetain(context);
    }
}
