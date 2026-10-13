#import "HGCore.h"
extern void HGTabAppearanceCaption(UIView *button);
static char HGTabFontKey;
@interface HGTabFontState : NSObject
@property(nonatomic, strong) UIFont *host;
@property(nonatomic, strong) UIFont *applied;
@end
@implementation HGTabFontState @end
static UIView *HGTabAncestor(UIView *view) {
    for (UIView *node = view; node; node = node.superview) if (HGIsClass(node, @"SSTabBar")) return node;
    return nil;
}
static BOOL HGTabActive(UIView *view) { return HGEnabled() && view.window != nil; }
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
void HGInstallTabBar(void) {
    // Font only. No tab frame/layout, controller placement, background, hit-test or lifecycle hooks.
    HGHookLayout(@"SSTabBarTextButton", ^(UIView *button) { HGTabFonts(button, HGTabActive(button)); HGTabAppearanceCaption(button); });
}

