#import "HGCore.h"
void HGInstallChrome(void);
void HGInstallTabBar(void);
void HGInstallFeatures(void) {
    HGInstallChrome();
    HGInstallTabBar();
    // Native video rendering, viewport and paging remain untouched.
}

