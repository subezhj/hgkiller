#import "HGCore.h"
#import "HGGeometry.h"

static char HGTabStateKey, HGDecorationKey;
@interface HGTabState : NSObject
@property(nonatomic, strong) UIVisualEffectView *glass;
@property(nonatomic) CGFloat cornerRadius;
@property(nonatomic) BOOL clips;
@property(nonatomic) BOOL active;
@end
@implementation HGTabState
@end
@interface HGDecorationState : NSObject
@property(nonatomic, strong) UIColor *color;
@property(nonatomic) BOOL hidden;
@property(nonatomic) BOOL hideManaged;
@end
@implementation HGDecorationState
@end
static BOOL HGTabEligible(UIView *view) {
    for (UIView *node = view; node; node = node.superview) if (HGIsClass(node.nextResponder, @"SSTabBarController")) return YES;
    return NO;
}
static UIView *HGTabAncestor(UIView *view) {
    for (UIView *node = view; node; node = node.superview) if (HGIsClass(node, @"SSTabBar")) return node;
    return nil;
}
static BOOL HGTabActive(UIView *view) { return HGEnabled() && HGBool(@"tab.glass") && HGTabEligible(view); }
static CGRect HGTabFrame(UIView *view, CGRect frame) {
    if (!HGTabActive(view) || !view.superview || !view.window) return frame;
    HGRect rect = HGGlassRectWithHeight(CGRectGetWidth(view.window.bounds), CGRectGetHeight(view.window.bounds),
                                        view.window.safeAreaInsets.bottom, HGNumber(@"tab.height"));
    return [view.superview convertRect:CGRectMake(rect.x, rect.y, rect.width, rect.height) fromView:view.window];
}
static NSArray<UIView *> *HGTabButtons(UIView *row) {
    NSMutableArray *buttons = [NSMutableArray array];
    for (UIView *view in row.subviews) if (HGIsClass(view, @"SSTabBarTextButton")) [buttons addObject:view];
    return buttons;
}
static CGRect HGTabButtonFrame(UIView *button, CGRect host) {
    UIView *bar = HGTabAncestor(button);
    if (!bar || !HGTabActive(bar)) return host;
    NSArray *buttons = HGTabButtons(button.superview);
    NSUInteger index = [buttons indexOfObjectIdenticalTo:button];
    if (index == NSNotFound) return host;
    HGRect rect = HGTabButtonRect(CGRectGetWidth(bar.bounds), CGRectGetHeight(bar.bounds), index, buttons.count);
    return CGRectMake(rect.x, rect.y, rect.width, rect.height);
}
static void HGCenterTabText(UIView *button) {
    UIView *bar = HGTabAncestor(button);
    BOOL active = bar && HGTabActive(bar);
    if (active) HGSetFrame(button, HGTabButtonFrame(button, HGHostFrame(button)));
    else HGRestoreFrame(button);
    for (UIView *child in button.subviews) {
        if (HGIsClass(child, @"CYLLabel")) continue; // Badge, not the caption.
        BOOL caption = [child isKindOfClass:UILabel.class] || [child isMemberOfClass:UIView.class];
        if (!caption && !HGIsClass(child, @"LOTAnimationView")) continue;
        if (active && !CGRectIsEmpty(child.bounds)) {
            CGRect frame = HGHostFrame(child);
            frame.origin = CGPointMake((CGRectGetWidth(button.bounds) - frame.size.width) / 2.0,
                                       (CGRectGetHeight(button.bounds) - frame.size.height) / 2.0);
            HGSetFrame(child, frame);
        } else if (!active) HGRestoreFrame(child);
    }
}
static void HGDecoration(UIView *view, BOOL active, BOOL hide) {
    HGDecorationState *state = objc_getAssociatedObject(view, &HGDecorationKey);
    if (active) {
        if (!state) {
            state = [HGDecorationState new]; state.color = view.backgroundColor; state.hidden = view.hidden;
            objc_setAssociatedObject(view, &HGDecorationKey, state, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        }
        if (![view.backgroundColor isEqual:UIColor.clearColor] && view.backgroundColor != nil) state.color = view.backgroundColor;
        state.hideManaged |= hide;
        HGApply(^{
            if (![view.backgroundColor isEqual:UIColor.clearColor]) view.backgroundColor = UIColor.clearColor;
            // Hiding the old material/image matters: clearColor does not remove their rendered pixels.
            if (hide && !view.hidden) view.hidden = YES;
        });
    } else if (state) {
        HGApply(^{
            if (![view.backgroundColor isEqual:state.color]) view.backgroundColor = state.color;
            if (state.hideManaged && view.hidden != state.hidden) view.hidden = state.hidden;
        });
        objc_setAssociatedObject(view, &HGDecorationKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
}
@protocol HGGlassEffectAPI <NSObject>
- (instancetype)initWithStyle:(NSInteger)style;
- (void)setInteractive:(BOOL)interactive;
@end
static UIVisualEffect *HGMakeGlassEffect(void) {
    Class cls = NSClassFromString(@"UIGlassEffect");
    if (cls && [cls instancesRespondToSelector:@selector(initWithStyle:)]) {
        id effect = [(id<HGGlassEffectAPI>)[cls alloc] initWithStyle:0];
        if ([effect isKindOfClass:UIVisualEffect.class]) {
            if ([effect respondsToSelector:@selector(setInteractive:)]) [(id<HGGlassEffectAPI>)effect setInteractive:YES];
            return effect;
        }
    }
    return [UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemUltraThinMaterial];
}
static void HGLayoutTab(UIView *view) {
    BOOL active = HGTabActive(view);
    HGTabState *state = objc_getAssociatedObject(view, &HGTabStateKey);
    if (!state && !active) return;
    if (!state) {
        state = [HGTabState new]; state.cornerRadius = view.layer.cornerRadius; state.clips = view.clipsToBounds;
        objc_setAssociatedObject(view, &HGTabStateKey, state, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    if (active) HGSetFrame(view, HGTabFrame(view, HGHostFrame(view)));
    else HGRestoreFrame(view);
    HGDecoration(view, active, NO);
    NSMutableArray *rows = [NSMutableArray array];
    for (UIView *child in view.subviews) {
        if (child == state.glass || [child isKindOfClass:UIControl.class] || HGIsClass(child, @"SSTabBarTextButton")) continue;
        NSArray *buttons = HGTabButtons(child);
        if (buttons.count) {
            [rows addObject:child];
            HGDecoration(child, active, NO);
            continue;
        }
        BOOL material = [child isKindOfClass:UIVisualEffectView.class] ||
                        [NSStringFromClass(child.class) hasPrefix:@"_UIBarBackground"];
        CGRect original = HGHostFrame(child);
        BOOL fullBackground = ([child isKindOfClass:UIImageView.class] || [child isMemberOfClass:UIView.class]) &&
                              original.size.width >= CGRectGetWidth(HGHostFrame(view)) * 0.85;
        if (material || fullBackground) HGDecoration(child, active, YES);
    }
    UIView *custom = HGFindView(view.superview, @"SSTabBar");
    BOOL backdrop = HGIsClass(view, @"SSTabBar") || !custom || custom.hidden || custom.alpha < 0.01;
    if (active && backdrop) {
        if (!state.glass) {
            state.glass = [[UIVisualEffectView alloc] initWithEffect:HGMakeGlassEffect()];
            state.glass.userInteractionEnabled = NO;
            state.glass.accessibilityElementsHidden = YES;
            [view insertSubview:state.glass atIndex:0];
        }
        HGApply(^{
            if (!CGRectEqualToRect(state.glass.frame, view.bounds)) state.glass.frame = view.bounds;
            CGFloat radius = CGRectGetHeight(view.bounds) / 2.0;
            if (state.glass.layer.cornerRadius != radius) state.glass.layer.cornerRadius = radius;
            if (!state.glass.clipsToBounds) state.glass.clipsToBounds = YES;
            if (view.layer.cornerRadius != radius) view.layer.cornerRadius = radius;
            if (!view.clipsToBounds) view.clipsToBounds = YES;
        });
    } else if (state.glass) {
        [state.glass removeFromSuperview]; state.glass = nil;
    }
    if (!active && state.active) {
        view.layer.cornerRadius = state.cornerRadius;
        view.clipsToBounds = state.clips;
    }
    for (UIView *row in rows) {
        if (active) HGSetFrame(row, view.bounds); else HGRestoreFrame(row);
        for (UIView *button in HGTabButtons(row)) {
            if (active) HGSetFrame(button, HGTabButtonFrame(button, HGHostFrame(button)));
            else HGRestoreFrame(button);
            HGCenterTabText(button);
        }
    }
    for (UIView *button in HGTabButtons(view)) HGCenterTabText(button);
    state.active = active;
}
static void HGDistributionStyle(UIView *view, NSUInteger depth, BOOL active) {
    HGDecoration(view, active, NO);
    if (depth == 0) return;
    for (UIView *child in view.subviews) {
        if ([child isKindOfClass:UIControl.class] || [child isKindOfClass:UILabel.class]) continue;
        if (HGIsClass(child, @"SSShortVideoDistributionContentView") ||
            ([child isMemberOfClass:UIView.class] && child.bounds.size.width >= view.bounds.size.width * 0.9)) {
            HGDistributionStyle(child, depth - 1, active);
        }
    }
}
void HGInstallTabBar(void) {
    HGHookLayout(@"SSShortVideoBottomDistributionView", ^(UIView *view) {
        HGDistributionStyle(view, 3, HGEnabled() && HGBool(@"tab.glass") && HGIsFeedView(view));
    });
    for (NSString *name in @[@"CYLTabBar", @"SSTabBar"]) {
        HGHookFrame(name, ^CGRect(UIView *view, CGRect frame) { return HGTabFrame(view, frame); });
        HGHookLayout(name, ^(UIView *view) { HGLayoutTab(view); });
    }
    // Enforce the slot in the host's frame write, including writes after the parent's layout callback.
    HGHookFrame(@"SSTabBarTextButton", ^CGRect(UIView *view, CGRect frame) { return HGTabButtonFrame(view, frame); });
    HGHookLayout(@"SSTabBarTextButton", ^(UIView *view) { HGCenterTabText(view); });
    HGHookControllerLayout(@"SSTabBarController", ^(UIViewController *controller) {
        for (NSString *name in @[@"CYLTabBar", @"SSTabBar"]) {
            UIView *bar = HGFindView(controller.view, name);
            if (bar) HGLayoutTab(bar);
        }
    });
}
