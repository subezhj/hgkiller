#import "HGCore.h"
#import "HGGeometry.h"

static char HGRightStateKey, HGFontStateKey;
static NSArray<NSString *> *HGRightClasses(void) {
    return @[@"SSShortVideoRightInteractionAvatarView", @"SSShortVideoRightInteractionCollectView",
             @"SSShortVideoRightInteractionCommentView", @"SSShortVideoRightInteractionLikeView",
             @"SSShortVideoRightInteractionShareView"];
}
static NSString *HGRightKey(UIView *view) {
    NSArray *classes = HGRightClasses();
    NSArray *keys = @[@"right.avatar", @"right.collect", @"right.comment", @"right.like", @"right.share"];
    for (NSUInteger i = 0; i < classes.count; i++) if (HGIsClass(view, classes[i])) return keys[i];
    return nil;
}
@interface HGRightState : NSObject
@property(nonatomic) BOOL hostHidden;
@property(nonatomic) CATransform3D hostSublayers;
@property(nonatomic) CATransform3D appliedSublayers;
@property(nonatomic) BOOL scaled;
@end
@implementation HGRightState
@end
@interface HGFontState : NSObject
@property(nonatomic, strong) UIFont *host;
@property(nonatomic, strong) UIFont *applied;
@end
@implementation HGFontState
@end
static HGRightState *HGRightStateFor(UIView *view) {
    HGRightState *state = objc_getAssociatedObject(view, &HGRightStateKey);
    if (!state) {
        state = [HGRightState new];
        state.hostHidden = view.hidden;
        state.hostSublayers = view.layer.sublayerTransform;
        objc_setAssociatedObject(view, &HGRightStateKey, state, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    return state;
}
static NSArray<UIView *> *HGRightItems(UIView *container) {
    NSMutableArray *items = [NSMutableArray array];
    // Stable semantic order, including the four-button variant found in the latest dump.
    for (NSString *name in HGRightClasses()) {
        for (UIView *view in container.subviews) if (HGIsClass(view, name)) [items addObject:view];
    }
    return items;
}
static BOOL HGRightHidden(UIView *view) {
    HGRightState *state = HGRightStateFor(view);
    return state.hostHidden || (HGEnabled() && HGIsFeedView(view) && !HGBool(HGRightKey(view)));
}
static CGRect HGRightTargetFrame(UIView *item, CGRect host) {
    UIView *container = item.superview;
    if (!HGEnabled() || !HGIsFeedView(item) || !HGIsClass(container, @"SSShortVideoRightInteractionView")) return host;
    NSArray *items = HGRightItems(container);
    CGFloat total = 0, gap = 12.0;
    NSUInteger visible = 0;
    for (UIView *view in items) if (!HGRightHidden(view)) {
        total += HGHostFrame(view).size.height;
        visible++;
    }
    total += gap * MAX(0, (NSInteger)visible - 1);
    CGFloat y = MAX(0.0, CGRectGetHeight(container.bounds) - total);
    for (UIView *view in items) {
        if (HGRightHidden(view)) continue;
        if (view == item) { host.origin.y = y; break; }
        y += HGHostFrame(view).size.height + gap;
    }
    return host;
}
static void HGApplyRightItem(UIView *item) {
    HGRightState *state = HGRightStateFor(item);
    BOOL active = HGEnabled() && HGIsFeedView(item);
    BOOL hidden = HGRightHidden(item);
    if (item.hidden != hidden) HGApply(^{ item.hidden = hidden; });
    if (state.scaled && !CATransform3DEqualToTransform(item.layer.sublayerTransform, state.appliedSublayers)) {
        state.hostSublayers = item.layer.sublayerTransform;
    }
    CATransform3D target = active ? CATransform3DConcat(state.hostSublayers,
        CATransform3DMakeScale(HGNumber(@"right.scale"), HGNumber(@"right.scale"), 1.0)) : state.hostSublayers;
    // Scale pixels inside the unchanged hit-test view. Never reset UIView.transform or bounds in layout.
    if (!CATransform3DEqualToTransform(item.layer.sublayerTransform, target)) {
        HGApply(^{ item.layer.sublayerTransform = target; });
    }
    state.appliedSublayers = target;
    state.scaled = active;
    if (active) HGSetFrame(item, HGRightTargetFrame(item, HGHostFrame(item)));
    else HGRestoreFrame(item);
}
static BOOL HGInHeader(UIView *view) {
    for (UIView *parent = view; parent; parent = parent.superview) if (HGIsClass(parent, @"SSVideoSeriesFeedHeaderView")) return YES;
    return NO;
}
static void HGScaleHeaderFonts(UIView *root) {
    if ([root isKindOfClass:UILabel.class]) {
        UILabel *label = (id)root;
        HGFontState *state = objc_getAssociatedObject(label, &HGFontStateKey);
        BOOL active = HGEnabled() && HGBool(@"top.enabled") && HGIsFeedView(root) && HGInHeader(root);
        if (!state && active) {
            state = [HGFontState new]; state.host = label.font;
            objc_setAssociatedObject(label, &HGFontStateKey, state, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        }
        if (state) {
            if (!state.applied || ![label.font isEqual:state.applied]) state.host = label.font;
            UIFont *font = active ? [state.host fontWithSize:MAX(10, state.host.pointSize * HGNumber(@"top.scale"))] : state.host;
            if (![label.font isEqual:font]) HGApply(^{ label.font = font; });
            state.applied = active ? font : nil;
        }
    }
    for (UIView *child in root.subviews) HGScaleHeaderFonts(child);
}
void HGInstallChrome(void) {
    HGHookLayout(@"SSShortVideoRightInteractionView", ^(UIView *container) {
        for (UIView *item in HGRightItems(container)) HGApplyRightItem(item);
    });
    for (NSString *name in HGRightClasses()) {
        HGHookFrame(name, ^CGRect(UIView *view, CGRect frame) { return HGRightTargetFrame(view, frame); });
        HGHookLayout(name, ^(UIView *view) { HGApplyRightItem(view); });
        SEL hidden = @selector(setHidden:);
        HGInstall(NSClassFromString(name), hidden, ^id(IMP original) {
            return ^(UIView *view, BOOL value) {
                if (!HGIsApplying()) {
                    HGRightStateFor(view).hostHidden = value;
                    value = HGRightHidden(view);
                }
                if (view.hidden != value) ((void (*)(id, SEL, BOOL))original)(view, hidden, value);
            };
        });
    }
    HGHookLayout(@"SSVideoSeriesFeedHeaderView", ^(UIView *view) { HGScaleHeaderFonts(view); });
    HGHookLayout(@"FQRJXCategoryCollectionView", ^(UIView *view) { if (HGInHeader(view)) HGScaleHeaderFonts(view); });
}
