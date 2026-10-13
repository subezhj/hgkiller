#import "HGCore.h"
void HGInstallChrome(void);
void HGInstallTabBar(void);
void HGInstallCaption(void);
void HGInstallTabAppearance(void);
void HGInstallFeatures(void) {
    HGInstallChrome();
    HGInstallTabBar();
    HGInstallCaption();
    HGInstallTabAppearance();
    // Native video rendering, viewport and paging remain untouched.
}



