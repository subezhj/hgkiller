#import "HGCore.h"

// Isolation build: only the captured SSTabBar may change geometry.
// No UICollectionView, layout-attribute, renderer or cell geometry hooks.
static char HGTabHeightKey;
static BOOL HGTabHeightUpdating;
@interface HGTabHeightState : NSObject
@property(nonatomic) CGRect source;
@property(nonatomic) CGRect applied;
@property(nonatomic) BOOL active;
@end
@implementation HGTabHeightState @end

static HGTabHeightState *HGTabHeight(UIView *bar) {
    HGTabHeightState *state = objc_getAssociatedObject(bar, &HGTabHeightKey);
    if (!state) {
        state = [HGTabHeightState new]; state.source = state.applied = bar.frame;
        objc_setAssociatedObject(bar, &HGTabHeightKey, state, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    return state;
}
static BOOL HGTabHeightEnabled(UIView *bar) {
    if (!HGEnabled() || !HGBool(@"tab.layout.enabled") || !bar.window ||
        bar.window.windowLevel != UIWindowLevelNormal || bar.window.bounds.size.height <= bar.window.bounds.size.width) return NO;
    for (UIView *view = bar; view; view = view.superview) if (view.hidden || view.alpha < 0.01) return NO;
    return YES;
}
static CGRect HGTabHeightTarget(UIView *bar, CGRect source) {
    if (!HGTabHeightEnabled(bar)) return source;
    CGFloat height = MIN(source.size.height, MAX(bar.window.safeAreaInsets.bottom + 28, HGNumber(@"tab.appearance.height")));
    CGRect target = source; target.origin.y = CGRectGetMaxY(source) - height; target.size.height = height;
    return target;
}
void HGReflowTabAllocation(UIView *bar) {
    if (!bar.window || HGIsApplying() || HGTabHeightUpdating) return;
    HGTabHeightUpdating = YES;
    @try {
        HGTabHeightState *state = HGTabHeight(bar);
        if (!state.active || !CGRectEqualToRect(bar.frame, state.applied)) state.source = bar.frame;
        CGRect target = HGTabHeightTarget(bar, state.source);
        state.applied = target; state.active = !CGRectEqualToRect(target, state.source);
        if (!CGRectEqualToRect(bar.frame, target)) HGApply(^{ bar.frame = target; });
    } @finally { HGTabHeightUpdating = NO; }
}
void HGInstallTabAllocation(void) {
    SEL setter = @selector(setFrame:);
    HGInstall(NSClassFromString(@"SSTabBar"), setter, ^id(IMP original) {
        return ^(UIView *bar, CGRect frame) {
            HGRecordHeightLayout(bar, setter);
            if (HGIsApplying()) { ((void (*)(id, SEL, CGRect))original)(bar, setter, frame); return; }
            HGTabHeightState *state = HGTabHeight(bar);
            if (!state.active || !CGRectEqualToRect(frame, state.applied)) state.source = frame;
            CGRect target = HGTabHeightTarget(bar, state.source);
            state.applied = target; state.active = !CGRectEqualToRect(target, state.source);
            if (state.active && CGRectEqualToRect(bar.frame, target)) return;
            ((void (*)(id, SEL, CGRect))original)(bar, setter, target);
        };
    });
    HGHookControllerLayout(@"SSTabBarController", ^(UIViewController *controller) {
        UIView *bar = HGFindView(controller.view, @"SSTabBar"); if (bar) HGReflowTabAllocation(bar);
    });
}
