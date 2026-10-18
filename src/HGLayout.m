#import "HGCore.h"
void HGInstallChrome(void);
void HGInstallTabBar(void);
void HGInstallCaption(void);
void HGInstallTabAppearance(void);
void HGInstallTabAllocation(void);
void HGInstallViewing(void);
void HGInstallFeatures(void) {
    HGInstallChrome();
    HGInstallTabBar();
    HGInstallCaption();
    HGInstallViewing();
    HGInstallTabAllocation();
    HGInstallVideoExperiment();
    HGInstallTabAppearance();
    // Native viewport/paging remain untouched; render-only experiment is opt-in.
}



