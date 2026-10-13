#import "HGCore.h"
#import <math.h>

static char HGTabFontKey, HGNativeTabKey;
@interface HGTabFontState : NSObject
@property(nonatomic, strong) UIFont *host;
@property(nonatomic, strong) UIFont *applied;
@end
@implementation HGTabFontState @end
@interface HGNativeTabState : NSObject
@property(nonatomic) BOOL clips;
@property(nonatomic, strong) CALayer *underlay;
@property(nonatomic) BOOL active;
@end
@implementation HGNativeTabState @end

static UIView *HGTabAncestor(UIView *view) {
    for (UIView *node = view; node; node = node.superview) if (HGIsClass(node, @"SSTabBar")) return node;
    return nil;
}
static BOOL HGTabActive(UIView *view) {
    if (!HGEnabled() || !view.window) return NO;
    for (UIView *node = view; node; node = node.superview)
        if (HGIsClass(node.nextResponder, @"SSTabBarController")) return YES;
    return NO;
}
static CGFloat HGTabButtonHeight(UIView *bar, CGRect native) {
    CGFloat safe = MIN(bar.window.safeAreaInsets.bottom, native.size.height);
    CGFloat available = MAX(0, native.size.height - safe);
    CGFloat total = MIN(native.size.height, MAX(safe + 28, HGNumber(@"tab.backgroundHeight")));
    return MIN(available, MAX(0, total - safe));
}
static CGRect HGTabFrame(UIView *bar, CGRect native) {
    if (!HGTabActive(bar) || native.size.height <= 0) return native;
    CGFloat safe = MIN(bar.window.safeAreaInsets.bottom, native.size.height);
    CGFloat height = HGTabButtonHeight(bar, native) + safe;
    // Stay entirely inside the native reserved strip; never touch feed safe areas or viewport.
    CGRect target = native;
    target.origin.y = CGRectGetMaxY(native) - height;
    target.size.height = height;
    return target;
}
static void HGTabFonts(UIView *view, BOOL active) {
    if ([view isKindOfClass:UILabel.class] && !HGIsClass(view, @"CYLLabel")) {
        UILabel *label = (id)view;
        HGTabFontState *state = objc_getAssociatedObject(label, &HGTabFontKey);
        if (!state) { state = [HGTabFontState new]; state.host = label.font; objc_setAssociatedObject(label, &HGTabFontKey, state, OBJC_ASSOCIATION_RETAIN_NONATOMIC); }
        if (!state.applied || ![label.font isEqual:state.applied]) state.host = label.font;
        UIFont *font = active ? [state.host fontWithSize:MAX(10, state.host.pointSize * HGNumber(@"tab.textScale"))] : state.host;
        if (![label.font isEqual:font]) HGApply(^{ label.font = font; });
        state.applied = active ? font : nil;
    }
    for (UIView *child in view.subviews) HGTabFonts(child, active);
}
static BOOL HGHasCaption(UIView *view) {
    if (HGIsClass(view, @"CYLLabel")) return NO;
    if ([view isKindOfClass:UILabel.class]) return YES;
    for (UIView *child in view.subviews) if (HGHasCaption(child)) return YES;
    return NO;
}
static char HGNativeCaptionKey;
@interface HGCaptionState : NSObject
@property(nonatomic) CATransform3D host;
@property(nonatomic) BOOL shifted;
@end
@implementation HGCaptionState @end
static void HGTabCaption(UIView *button) {
    UIView *bar = HGTabAncestor(button);
    BOOL active = bar && HGTabActive(bar);
    HGTabFonts(button, active);
    HGCaptionState *state = objc_getAssociatedObject(button, &HGNativeCaptionKey);
    if (!state) { state = [HGCaptionState new]; state.host = button.layer.sublayerTransform; objc_setAssociatedObject(button, &HGNativeCaptionKey, state, OBJC_ASSOCIATION_RETAIN_NONATOMIC); }
    CATransform3D target = state.host;
    if (active) {
        UIView *caption = nil;
        for (UIView *child in button.subviews) if (HGHasCaption(child)) { caption = child; break; }
        if (caption) target = CATransform3DTranslate(state.host, 0, HGTabButtonHeight(bar, HGHostFrame(bar)) / 2 - caption.center.y, 0);
    }
    // Only native tab text pixels move vertically; all title/caption/video views outside the tab stay untouched.
    HGApply(^{ if (!CATransform3DEqualToTransform(button.layer.sublayerTransform, target)) button.layer.sublayerTransform = target; });
    state.shifted = active;
}
static void HGLayoutTab(UIView *bar) {
    BOOL active = HGTabActive(bar);
    HGNativeTabState *state = objc_getAssociatedObject(bar, &HGNativeTabKey);
    if (!state) { state = [HGNativeTabState new]; state.clips = bar.clipsToBounds; objc_setAssociatedObject(bar, &HGNativeTabKey, state, OBJC_ASSOCIATION_RETAIN_NONATOMIC); }
    if (active) {
        if (!state.underlay) {
            state.underlay = [CALayer layer]; state.underlay.name = @"HGK.nativeTabUnderlay";
            state.underlay.backgroundColor = UIColor.blackColor.CGColor;
        }
        [CATransaction begin]; [CATransaction setDisableActions:YES];
        if (state.underlay.superlayer != bar.layer.superlayer) {
            [state.underlay removeFromSuperlayer];
            [bar.layer.superlayer insertSublayer:state.underlay below:bar.layer];
        }
        state.underlay.hidden = bar.hidden || bar.alpha < 0.01;
        CGRect reserved = HGHostFrame(bar);
        CGRect backing = HGTabFrame(bar, reserved);
        if (!CGRectEqualToRect(state.underlay.frame, backing)) state.underlay.frame = backing;
        [CATransaction commit];
        HGSetFrame(bar, HGTabFrame(bar, reserved));
    } else {
        [state.underlay removeFromSuperlayer]; state.underlay = nil;
        HGRestoreFrame(bar);
    }
    HGApply(^{ if (bar.clipsToBounds != (active ? YES : state.clips)) bar.clipsToBounds = active ? YES : state.clips; });
    for (UIView *child in bar.subviews) {
        if (HGIsClass(child, @"SSTabBarTextButton")) HGTabCaption(child);
        else for (UIView *button in child.subviews) if (HGIsClass(button, @"SSTabBarTextButton")) HGTabCaption(button);
    }
    state.active = active;
}
BOOL HGHandleTabFont(UILabel *label, UIFont *font, void (^apply)(UIFont *)) {
    UIView *bar = HGTabAncestor(label);
    if (!bar || HGIsApplying() || !font || HGIsClass(label, @"CYLLabel")) return NO;
    HGTabFontState *state = objc_getAssociatedObject(label, &HGTabFontKey);
    if (!state) { state = [HGTabFontState new]; objc_setAssociatedObject(label, &HGTabFontKey, state, OBJC_ASSOCIATION_RETAIN_NONATOMIC); }
    if (![font isEqual:state.applied]) state.host = font;
    BOOL active = HGTabActive(bar);
    UIFont *output = active ? [state.host fontWithSize:MAX(10, state.host.pointSize * HGNumber(@"tab.textScale"))] : state.host;
    state.applied = active ? output : nil;
    if (![label.font isEqual:output]) apply(output);
    return YES;
}
static void HGSyncUnderlay(UIView *bar) {
    HGNativeTabState *state = objc_getAssociatedObject(bar, &HGNativeTabKey);
    BOOL hidden = bar.hidden || bar.alpha < 0.01;
    if (state.underlay && state.underlay.hidden != hidden) state.underlay.hidden = hidden;
}
void HGInstallTabBar(void) {
    SEL moved = @selector(didMoveToWindow);
    HGInstall(NSClassFromString(@"SSTabBar"), moved, ^id(IMP original) {
        return ^(UIView *bar) {
            ((void (*)(id, SEL))original)(bar, moved);
            if (bar.window && !HGIsApplying()) { HGLayoutTab(bar); HGRefreshViews(); }
        };
    });
    HGInstall(NSClassFromString(@"SSShortVideoBottomDistributionView"), moved, ^id(IMP original) {
        return ^(UIView *view) { ((void (*)(id, SEL))original)(view, moved); if (view.window) HGRefreshViews(); };
    });
    SEL hiddenSelector = @selector(setHidden:);
    HGInstall(NSClassFromString(@"SSTabBar"), hiddenSelector, ^id(IMP original) {
        return ^(UIView *bar, BOOL hidden) { ((void (*)(id, SEL, BOOL))original)(bar, hiddenSelector, hidden); HGSyncUnderlay(bar); };
    });
    SEL alphaSelector = @selector(setAlpha:);
    HGInstall(NSClassFromString(@"SSTabBar"), alphaSelector, ^id(IMP original) {
        return ^(UIView *bar, CGFloat alpha) { ((void (*)(id, SEL, CGFloat))original)(bar, alphaSelector, alpha); HGSyncUnderlay(bar); };
    });
    HGHookFrame(@"SSTabBar", ^CGRect(UIView *bar, CGRect frame) { return HGTabFrame(bar, frame); });
    HGHookLayout(@"SSTabBar", ^(UIView *bar) { HGLayoutTab(bar); });
    HGHookLayout(@"SSTabBarTextButton", ^(UIView *button) { HGTabCaption(button); });
    HGHookControllerLayout(@"SSTabBarController", ^(UIViewController *controller) {
        UIView *bar = HGFindView(controller.view, @"SSTabBar"); if (bar) HGLayoutTab(bar);
    });
    // No CYLTabBar, distribution, caption container, player or video layout hooks; native hit-testing stays intact.
}




