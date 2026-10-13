#import "HGCore.h"
#import "HGGeometry.h"

static char HGTabStateKey, HGDecorationKey, HGContentKey;
@interface HGTabState : NSObject
@property(nonatomic, strong) UIVisualEffectView *glass;
@property(nonatomic) CGFloat cornerRadius;
@property(nonatomic) BOOL clips;
@property(nonatomic) BOOL active;
@end
@implementation HGTabState @end
@interface HGDecorationState : NSObject
@property(nonatomic, strong) UIColor *color;
@property(nonatomic) BOOL hidden;
@property(nonatomic) BOOL hideManaged;
@end
@implementation HGDecorationState @end
@interface HGTabContentState : NSObject
@property(nonatomic) CATransform3D host;
@property(nonatomic) CATransform3D applied;
@property(nonatomic) BOOL hostClips;
@property(nonatomic) BOOL shifted;
@end
@implementation HGTabContentState @end

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
    HGRect r = HGGlassRectWithHeight(view.window.bounds.size.width, view.window.bounds.size.height,
                                    view.window.safeAreaInsets.bottom, HGNumber(@"tab.height"));
    return [view.superview convertRect:CGRectMake(r.x, r.y, r.width, r.height) fromView:view.window];
}
static NSArray<UIView *> *HGTabButtons(UIView *row) {
    NSMutableArray *buttons = [NSMutableArray array];
    for (UIView *view in row.subviews) if (HGIsClass(view, @"SSTabBarTextButton")) [buttons addObject:view];
    return buttons;
}
static NSArray<UIView *> *HGAllTabButtons(UIView *bar) {
    NSMutableArray *buttons = [HGTabButtons(bar) mutableCopy];
    for (UIView *child in bar.subviews) [buttons addObjectsFromArray:HGTabButtons(child)];
    return buttons;
}
static CGRect HGTabSlot(UIView *bar, UIView *button) {
    NSArray *buttons = HGAllTabButtons(bar);
    NSUInteger index = [buttons indexOfObjectIdenticalTo:button];
    if (index == NSNotFound) return CGRectNull;
    HGRect r = HGTabButtonRect(bar.bounds.size.width, bar.bounds.size.height, index, buttons.count);
    return CGRectMake(r.x, r.y, r.width, r.height);
}
static BOOL HGHasCaption(UIView *view) {
    if (HGIsClass(view, @"CYLLabel")) return NO;
    if ([view isKindOfClass:UILabel.class]) return YES;
    for (UIView *child in view.subviews) if (HGHasCaption(child)) return YES;
    return NO;
}
static void HGCenterTabPixels(UIView *button) {
    UIView *bar = HGTabAncestor(button);
    BOOL active = bar && HGTabActive(bar);
    HGTabContentState *state = objc_getAssociatedObject(button, &HGContentKey);
    if (!state && !active) return;
    if (!state) {
        state = [HGTabContentState new]; state.host = button.layer.sublayerTransform;
        state.hostClips = button.layer.masksToBounds;
        objc_setAssociatedObject(button, &HGContentKey, state, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    if (!active) {
        if (state.shifted) {
            HGApply(^{
                if (!CATransform3DEqualToTransform(button.layer.sublayerTransform, state.host)) button.layer.sublayerTransform = state.host;
                if (button.layer.masksToBounds != state.hostClips) button.layer.masksToBounds = state.hostClips;
            });
            state.shifted = NO;
        }
        return;
    }
    if (state.shifted && !CATransform3DEqualToTransform(button.layer.sublayerTransform, state.applied)) {
        state.host = button.layer.sublayerTransform;
    }
    UIView *caption = nil;
    for (UIView *child in button.subviews) if (HGHasCaption(child)) { caption = child; break; }
    CGRect slot = HGTabSlot(bar, button);
    if (!caption || CGRectIsNull(slot) || CGRectIsEmpty(caption.bounds)) return;
    CGPoint target = [button convertPoint:CGPointMake(CGRectGetMidX(slot), CGRectGetMidY(slot)) fromView:bar];
    CGPoint source = caption.center; // Host geometry is read, never overwritten.
    CATransform3D transform = CATransform3DTranslate(state.host, target.x - source.x, target.y - source.y, 0);
    HGApply(^{
        if (!CATransform3DEqualToTransform(button.layer.sublayerTransform, transform)) button.layer.sublayerTransform = transform;
        if (button.layer.masksToBounds) button.layer.masksToBounds = NO;
    });
    state.applied = transform; state.shifted = YES;
}
static void HGDecoration(UIView *view, BOOL active, BOOL hide) {
    HGDecorationState *state = objc_getAssociatedObject(view, &HGDecorationKey);
    if (active) {
        if (!state) {
            state = [HGDecorationState new]; state.color = view.backgroundColor; state.hidden = view.hidden;
            objc_setAssociatedObject(view, &HGDecorationKey, state, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        }
        if (view.backgroundColor && ![view.backgroundColor isEqual:UIColor.clearColor]) state.color = view.backgroundColor;
        state.hideManaged |= hide;
        HGApply(^{
            if (![view.backgroundColor isEqual:UIColor.clearColor]) view.backgroundColor = UIColor.clearColor;
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
    if (active) HGSetFrame(view, HGTabFrame(view, HGHostFrame(view))); else HGRestoreFrame(view);
    HGDecoration(view, active, NO);
    for (UIView *child in view.subviews) {
        if (child == state.glass || [child isKindOfClass:UIControl.class] || HGIsClass(child, @"SSTabBarTextButton")) continue;
        if (HGTabButtons(child).count) { HGDecoration(child, active, NO); continue; }
        BOOL material = [child isKindOfClass:UIVisualEffectView.class] || [NSStringFromClass(child.class) hasPrefix:@"_UIBarBackground"];
        CGRect original = HGHostFrame(child);
        BOOL background = ([child isKindOfClass:UIImageView.class] || [child isMemberOfClass:UIView.class]) &&
                          original.size.width >= CGRectGetWidth(HGHostFrame(view)) * 0.85;
        if (material || background) HGDecoration(child, active, YES);
    }
    UIView *custom = HGFindView(view.superview, @"SSTabBar");
    BOOL backdrop = HGIsClass(view, @"SSTabBar") || !custom || custom.hidden || custom.alpha < 0.01;
    if (active && backdrop) {
        if (!state.glass) {
            state.glass = [[UIVisualEffectView alloc] initWithEffect:HGMakeGlassEffect()];
            state.glass.userInteractionEnabled = NO; state.glass.accessibilityElementsHidden = YES;
            [view insertSubview:state.glass atIndex:0];
        }
        HGApply(^{
            if (!CGRectEqualToRect(state.glass.frame, view.bounds)) state.glass.frame = view.bounds;
            CGFloat radius = CGRectGetHeight(view.bounds) / 2;
            if (state.glass.layer.cornerRadius != radius) state.glass.layer.cornerRadius = radius;
            if (!state.glass.clipsToBounds) state.glass.clipsToBounds = YES;
            if (view.layer.cornerRadius != radius) view.layer.cornerRadius = radius;
            if (!view.clipsToBounds) view.clipsToBounds = YES;
        });
    } else if (state.glass) { [state.glass removeFromSuperview]; state.glass = nil; }
    if (!active && state.active) { view.layer.cornerRadius = state.cornerRadius; view.clipsToBounds = state.clips; }
    // The native row, button and caption frames stay intact; only rendered pixels are translated.
    for (UIView *button in HGAllTabButtons(view)) HGCenterTabPixels(button);
    state.active = active;
}
static void HGDistributionStyle(UIView *view, NSUInteger depth, BOOL active) {
    HGDecoration(view, active, NO);
    if (!depth) return;
    for (UIView *child in view.subviews) {
        if ([child isKindOfClass:UIControl.class] || [child isKindOfClass:UILabel.class]) continue;
        if (HGIsClass(child, @"SSShortVideoDistributionContentView") ||
            ([child isMemberOfClass:UIView.class] && child.bounds.size.width >= view.bounds.size.width * 0.9))
            HGDistributionStyle(child, depth - 1, active);
    }
}
void HGInstallTabBar(void) {
    HGHookLayout(@"SSShortVideoBottomDistributionView", ^(UIView *v) { HGDistributionStyle(v, 3, HGEnabled() && HGBool(@"tab.glass") && HGIsFeedView(v)); });
    for (NSString *name in @[@"CYLTabBar", @"SSTabBar"]) {
        HGHookFrame(name, ^CGRect(UIView *v, CGRect f) { return HGTabFrame(v, f); });
        HGHookLayout(name, ^(UIView *v) { HGLayoutTab(v); });
    }
    // No setFrame: hook on SSTabBarTextButton. Its Auto Layout geometry belongs to the host.
    HGHookLayout(@"SSTabBarTextButton", ^(UIView *v) { HGCenterTabPixels(v); });
    SEL hit = @selector(hitTest:withEvent:);
    HGInstall(NSClassFromString(@"SSTabBar"), hit, ^id(IMP original) {
        return ^UIView *(UIView *bar, CGPoint point, UIEvent *event) {
            if (HGTabActive(bar) && !bar.hidden && bar.alpha > 0.01 && bar.userInteractionEnabled && CGRectContainsPoint(bar.bounds, point)) {
                for (UIView *button in HGAllTabButtons(bar)) {
                    if (!button.hidden && button.alpha > 0.01 && button.userInteractionEnabled &&
                        CGRectContainsPoint(HGTabSlot(bar, button), point)) return button;
                }
            }
            return ((id (*)(id, SEL, CGPoint, id))original)(bar, hit, point, event);
        };
    });
    SEL inside = @selector(pointInside:withEvent:);
    HGInstall(NSClassFromString(@"SSTabBarTextButton"), inside, ^id(IMP original) {
        return ^BOOL(UIView *button, CGPoint point, UIEvent *event) {
            UIView *bar = HGTabAncestor(button);
            if (bar && HGTabActive(bar)) return CGRectContainsPoint(HGTabSlot(bar, button), [bar convertPoint:point fromView:button]);
            return ((BOOL (*)(id, SEL, CGPoint, id))original)(button, inside, point, event);
        };
    });
    HGHookControllerLayout(@"SSTabBarController", ^(UIViewController *controller) {
        for (NSString *name in @[@"CYLTabBar", @"SSTabBar"]) {
            UIView *bar = HGFindView(controller.view, name); if (bar) HGLayoutTab(bar);
        }
    });
}
