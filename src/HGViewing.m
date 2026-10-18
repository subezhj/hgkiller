#import "HGCore.h"
#import <math.h>
static char HGViewingStateKey;
@interface HGViewingState : NSObject
@property(nonatomic) BOOL hostHidden;
@property(nonatomic) BOOL appliedHidden;
@property(nonatomic) CGFloat hostAlpha;
@property(nonatomic) CGFloat appliedAlpha;
@property(nonatomic) BOOL alphaActive;
@end
@implementation HGViewingState @end
static HGViewingState *HGViewingStateFor(UIView *view) {
    HGViewingState *state = objc_getAssociatedObject(view, &HGViewingStateKey);
    if (!state) {
        state = [HGViewingState new]; state.hostHidden = state.appliedHidden = view.hidden;
        state.hostAlpha = state.appliedAlpha = view.alpha;
        objc_setAssociatedObject(view, &HGViewingStateKey, state, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    return state;
}
static BOOL HGViewingDetail(UIView *view) {
    BOOL detail = NO;
    for (UIView *node = view; node; node = node.superview) {
        if (HGIsClass(node.nextResponder, @"SSVideoSeriesFeedViewController")) return NO;
        if (HGIsClass(node.nextResponder, @"FQVShortVideoListViewController") || HGIsClass(node, @"SSShortVideoSingleSeriesInfoLeftContainerView")) detail = YES;
    }
    return detail;
}
static BOOL HGViewingScope(UIView *view) {
    return view.window && view.window.windowLevel == UIWindowLevelNormal &&
        view.window.bounds.size.height > view.window.bounds.size.width && (HGIsFeedView(view) || HGViewingDetail(view));
}
NSString *HGViewingKey(UIView *view, NSString *key) {
    return HGBool(@"profiles.enabled") && HGViewingDetail(view) ? [@"detail." stringByAppendingString:key] : key;
}
BOOL HGViewingHides(UIView *view, NSString *group) {
    return HGEnabled() && HGViewingScope(view) && HGBool(HGViewingKey(view, @"clean.enabled")) &&
        HGBool(HGViewingKey(view, [@"clean." stringByAppendingString:group]));
}
static NSString *HGViewingGroup(UIView *view) {
    if (HGIsClass(view, @"SSShortVideoRightInteractionView")) return @"right";
    if (HGIsClass(view, @"SSVideoSeriesFeedHeaderView")) return @"header";
    if (HGIsClass(view, @"SSShortVideoBottomDistributionView")) return @"distribution";
    if (HGIsClass(view, @"SSShortVideoOutterSeriesLeftContainerView") || HGIsClass(view, @"SSShortVideoSingleSeriesInfoLeftContainerView")) return @"caption";
    return nil;
}
static CGFloat HGShadeAlpha(UIView *view, HGViewingState *state) {
    BOOL active = HGEnabled() && HGViewingScope(view) && HGBool(HGViewingKey(view, @"shade.enabled"));
    state.alphaActive = active;
    BOOL top = view.superview.bounds.size.height > 0 ? CGRectGetMidY(view.frame) < view.superview.bounds.size.height / 2 : view.frame.origin.y <= 1;
    return active ? state.hostAlpha * HGNumber(HGViewingKey(view, top ? @"shade.top" : @"shade.bottom")) : state.hostAlpha;
}
void HGApplyViewing(UIView *view) {
    NSString *group = HGViewingGroup(view);
    if (group) {
        HGViewingState *state = HGViewingStateFor(view);
        if (view.hidden != state.appliedHidden) state.hostHidden = view.hidden;
        BOOL hidden = state.hostHidden || HGViewingHides(view, group); state.appliedHidden = hidden;
        if (view.hidden != hidden) HGApply(^{ view.hidden = hidden; });
    } else if (HGIsClass(view, @"FQVShortVideoGradientLayerView")) {
        HGViewingState *state = HGViewingStateFor(view);
        if (!state.alphaActive || fabs(view.alpha - state.appliedAlpha) > 0.0001) state.hostAlpha = view.alpha;
        CGFloat alpha = HGShadeAlpha(view, state); state.appliedAlpha = alpha;
        if (fabs(view.alpha - alpha) > 0.0001) HGApply(^{ view.alpha = alpha; });
    }
}
void HGInstallViewing(void) {
    for (NSString *name in @[@"SSShortVideoRightInteractionView", @"SSVideoSeriesFeedHeaderView", @"SSShortVideoBottomDistributionView",
                             @"SSShortVideoOutterSeriesLeftContainerView", @"SSShortVideoSingleSeriesInfoLeftContainerView"]) {
        SEL hidden = @selector(setHidden:);
        HGInstall(NSClassFromString(name), hidden, ^id(IMP original) {
            return ^(UIView *view, BOOL value) {
                if (!HGIsApplying()) {
                    HGViewingState *state = HGViewingStateFor(view); state.hostHidden = value;
                    value = value || HGViewingHides(view, HGViewingGroup(view)); state.appliedHidden = value;
                }
                if (view.hidden != value) ((void (*)(id, SEL, BOOL))original)(view, hidden, value);
            };
        });
        SEL moved = @selector(didMoveToWindow);
        HGInstall(NSClassFromString(name), moved, ^id(IMP original) {
            return ^(UIView *view) { ((void (*)(id, SEL))original)(view, moved); HGApplyViewing(view); };
        });
    }
    HGHookLayout(@"SSShortVideoBottomDistributionView", ^(UIView *view) { HGApplyViewing(view); });
    HGHookLayout(@"FQVShortVideoGradientLayerView", ^(UIView *view) { HGApplyViewing(view); });
    SEL moved = @selector(didMoveToWindow);
    HGInstall(NSClassFromString(@"FQVShortVideoGradientLayerView"), moved, ^id(IMP original) {
        return ^(UIView *view) { ((void (*)(id, SEL))original)(view, moved); HGApplyViewing(view); };
    });
    SEL alpha = @selector(setAlpha:);
    HGInstall(NSClassFromString(@"FQVShortVideoGradientLayerView"), alpha, ^id(IMP original) {
        return ^(UIView *view, CGFloat value) {
            if (!HGIsApplying()) {
                HGViewingState *state = HGViewingStateFor(view);
                state.hostAlpha = value;
                value = HGShadeAlpha(view, state); state.appliedAlpha = value;
            }
            if (fabs(view.alpha - value) > 0.0001) ((void (*)(id, SEL, CGFloat))original)(view, alpha, value);
        };
    });
}
