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
    // Native video rendering, viewport and paging remain untouched.
}



