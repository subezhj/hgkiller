#import "HGCore.h"
void HGInstallChrome(void);
void HGInstallTabBar(void);
void HGInstallFeatures(void) {
    HGInstallChrome();
    HGInstallTabBar();
    // 0.1.2: no feed layout, player, cell, HUD, progress or video geometry hooks.
}