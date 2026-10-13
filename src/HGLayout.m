#import "HGCore.h"
void HGInstallChrome(void);
void HGInstallTabBar(void);
void HGInstallCaption(void);
void HGInstallTabAppearance(void);
void HGInstallTabAllocation(void);
void HGInstallFeatures(void) {
    HGInstallChrome();
    HGInstallTabBar();
    HGInstallCaption();
    HGInstallTabAllocation();
    HGInstallTabAppearance();
    // Isolation: native viewport, paging and renderer geometry remain untouched.
}



