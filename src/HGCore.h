#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <objc/message.h>

FOUNDATION_EXPORT NSString *const HGPreferencePrefix;
FOUNDATION_EXPORT BOOL HGEnabled(void);
FOUNDATION_EXPORT BOOL HGBool(NSString *key);
FOUNDATION_EXPORT CGFloat HGNumber(NSString *key);
FOUNDATION_EXPORT void HGInitializePreferences(void);
FOUNDATION_EXPORT void HGWritePreference(NSString *key, id value);
FOUNDATION_EXPORT void HGResetPreferences(void);
FOUNDATION_EXPORT void HGRefreshViews(void);
FOUNDATION_EXPORT BOOL HGIsClass(id object, NSString *name);
FOUNDATION_EXPORT UIView *HGFindView(UIView *root, NSString *name);
FOUNDATION_EXPORT UIViewController *HGOwner(UIView *view);
FOUNDATION_EXPORT BOOL HGIsFeedView(UIView *view);
FOUNDATION_EXPORT BOOL HGIsApplying(void);
FOUNDATION_EXPORT void HGApply(dispatch_block_t block);
FOUNDATION_EXPORT BOOL HGInstall(Class cls, SEL selector, id (^builder)(IMP original));
FOUNDATION_EXPORT void HGHookLayout(NSString *name, void (^callback)(UIView *view));
FOUNDATION_EXPORT void HGHookControllerLayout(NSString *name, void (^callback)(UIViewController *controller));
FOUNDATION_EXPORT void HGHookFrame(NSString *name, CGRect (^adjust)(UIView *view, CGRect frame));
FOUNDATION_EXPORT void HGSetFrame(UIView *view, CGRect frame);
FOUNDATION_EXPORT void HGRestoreFrame(UIView *view);
FOUNDATION_EXPORT CGRect HGHostFrame(UIView *view);
FOUNDATION_EXPORT void HGInstallFeatures(void);
FOUNDATION_EXPORT void HGInstallSettings(void);
FOUNDATION_EXPORT NSArray<NSString *> *HGMissingClasses(void);

FOUNDATION_EXPORT NSString *HGSafetyReason(void);

FOUNDATION_EXPORT BOOL HGSafetyPaused(void);
FOUNDATION_EXPORT void HGClearSafetyRecord(void);
FOUNDATION_EXPORT NSString *const HGPreferencesDidChangeNotification;
FOUNDATION_EXPORT void HGHeightBeginAttempt(void);
FOUNDATION_EXPORT void HGRecordHeightLayout(id object, SEL selector);
FOUNDATION_EXPORT NSString *HGHeightDiagnosticText(void);
FOUNDATION_EXPORT NSString *HGViewingKey(UIView *view, NSString *key);
FOUNDATION_EXPORT BOOL HGViewingHides(UIView *view, NSString *group);
FOUNDATION_EXPORT void HGApplyViewing(UIView *view);
FOUNDATION_EXPORT void HGRefreshLandscape(UIViewController *controller);
FOUNDATION_EXPORT NSString *HGLandscapeDiagnosticText(void);
FOUNDATION_EXPORT BOOL HGPlaybackVisible(UIView *view);
FOUNDATION_EXPORT UIView *HGCurrentPicture(UIView *root);
FOUNDATION_EXPORT void HGLiquidTabLayout(UIView *bar);
FOUNDATION_EXPORT NSString *HGLiquidDiagnosticText(void);
FOUNDATION_EXPORT void HGUpdateVideoExperiment(UIView *bar);
FOUNDATION_EXPORT void HGRestoreVideoExperiment(void);
FOUNDATION_EXPORT BOOL HGVideoCoversBar(UIView *bar);
FOUNDATION_EXPORT void HGInstallVideoExperiment(void);
FOUNDATION_EXPORT NSString *HGVideoExperimentStatus(void);
