#import "HGCore.h"
void HGInstallChrome(void);
void HGInstallTabBar(void);
void HGInstallVideoSurface(void);
void HGInstallFeatures(void) {
    HGInstallChrome();
    HGInstallTabBar();
    HGInstallVideoSurface();
    // Native paging and player geometry remain unchanged; surface projection only.
}
