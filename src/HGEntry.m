#import "HGCore.h"

static void HGStart(void) {
    HGInitializePreferences();
    HGInstallFeatures();
    HGInstallSettings();
}
__attribute__((constructor))
static void HGLoad(void) {
    @autoreleasepool {
        if (![NSBundle.mainBundle.bundleIdentifier isEqualToString:@"com.phoenix.video"]) return;
        dispatch_async(dispatch_get_main_queue(), ^{
            HGStart();
            // Some embedded modules are loaded after the main executable. Installation is idempotent.
            for (NSUInteger retry = 1; retry <= 3; retry++) {
                dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(retry * NSEC_PER_SEC)),
                               dispatch_get_main_queue(), ^{
                    HGInstallFeatures();
                    HGInstallSettings();
                });
            }
        });
    }
}
