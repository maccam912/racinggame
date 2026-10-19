#import <CoreFoundation/CoreFoundation.h>
#import <LocalAuthentication/LocalAuthentication.h>
#import <AppKit/AppKit.h>
#import <CoreGraphics/CoreGraphics.h>

extern "C" CFArrayRef pacific_screen_modes(int screen) {
    @autoreleasepool {
        NSArray<NSScreen *> *screens = [NSScreen screens];
        if (screen < 0 || screen >= (int)screens.count) return nullptr;
        NSNumber *number = screens[screen].deviceDescription[@"NSScreenNumber"];
        if (!number) return nullptr;
        return CGDisplayCopyAllDisplayModes(number.unsignedIntValue, nullptr);
    }
}

extern "C" CFTypeRef pacific_no_ui_auth_context() {
    @autoreleasepool {
        LAContext *context = [LAContext new];
        context.interactionNotAllowed = YES;
        return CFBridgingRetain(context);
    }
}
