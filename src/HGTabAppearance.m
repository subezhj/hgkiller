#import "HGCore.h"
static char HGAppearanceKey, HGOpacityKey, HGAppearanceCaptionKey, HGRowColorKey;
@interface HGAppearance : NSObject
@property(nonatomic, strong) UIColor *hostBackground;
@property(nonatomic) BOOL hostClips;
@property(nonatomic, strong) UIVisualEffectView *blur;
@end
@implementation HGAppearance @end
@interface HGAppearanceCaption : NSObject
@property(nonatomic) CATransform3D host;
@end
@implementation HGAppearanceCaption @end
void HGReflowTabAllocation(UIView *bar);
static UIView *HGAppearanceBar(UIView *view) {
    for (UIView *node = view; node; node = node.superview) if (HGIsClass(node, @"SSTabBar")) return node;
    return nil;
}
static BOOL HGAppearanceActive(UIView *bar) { return bar && bar.window && HGEnabled() && !HGBool(@"tab.liquid.enabled") && HGBool(@"tab.appearance.enabled"); }
static BOOL HGCaptionChild(UIView *view) {
    if (HGIsClass(view, @"CYLLabel")) return NO;
    if ([view isKindOfClass:UILabel.class]) return YES;
    for (UIView *child in view.subviews) if (HGCaptionChild(child)) return YES;
    return NO;
}
void HGTabAppearanceCaption(UIView *button) {
    UIView *bar = HGAppearanceBar(button);
    HGAppearanceCaption *state = objc_getAssociatedObject(button, &HGAppearanceCaptionKey);
    BOOL active = HGAppearanceActive(bar) || (bar && HGEnabled() && !HGBool(@"tab.liquid.enabled") && HGBool(@"tab.layout.enabled"));
    if (!state && !active) return;
    if (!state) { state = [HGAppearanceCaption new]; state.host = button.layer.sublayerTransform; objc_setAssociatedObject(button, &HGAppearanceCaptionKey, state, OBJC_ASSOCIATION_RETAIN_NONATOMIC); }
    CATransform3D target = state.host;
    if (active) {
        CGFloat h = HGBool(@"tab.layout.enabled") ? MIN(bar.bounds.size.height, HGNumber(@"tab.appearance.height")) : bar.bounds.size.height;
        CGFloat safe = MIN(bar.window.safeAreaInsets.bottom, h);
        CGFloat center = bar.bounds.size.height - h + (h - safe) / 2;
        for (UIView *child in button.subviews) if (HGCaptionChild(child)) {
            CGPoint original = [bar convertPoint:child.center fromView:button];
            target = CATransform3DTranslate(state.host, 0, center - original.y, 0); break;
        }
    }
    HGApply(^{ if (!CATransform3DEqualToTransform(button.layer.sublayerTransform, target)) button.layer.sublayerTransform = target; });
}
static void HGAppearanceLayout(UIView *bar) {
    BOOL liquid = HGEnabled() && HGBool(@"tab.liquid.enabled");
    if (!liquid) HGLiquidTabLayout(bar);
    HGReflowTabAllocation(bar);
    HGAppearance *state = objc_getAssociatedObject(bar, &HGAppearanceKey);
    BOOL active = HGAppearanceActive(bar);
    BOOL allocation = HGEnabled() && !liquid && HGBool(@"tab.layout.enabled");
    if (!state && !active && !allocation) { if (liquid) HGLiquidTabLayout(bar); return; }
    if (!state) { state = [HGAppearance new]; state.hostBackground = bar.backgroundColor; state.hostClips = bar.clipsToBounds; objc_setAssociatedObject(bar, &HGAppearanceKey, state, OBJC_ASSOCIATION_RETAIN_NONATOMIC); }
    if (bar.clipsToBounds != (allocation ? YES : state.hostClips)) bar.clipsToBounds = allocation ? YES : state.hostClips;
    if (active && !state.blur) {
        state.blur = [[UIVisualEffectView alloc] initWithEffect:[UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemUltraThinMaterialDark]];
        state.blur.overrideUserInterfaceStyle = UIUserInterfaceStyleDark;
        state.blur.userInteractionEnabled = NO; state.blur.accessibilityElementsHidden = YES; state.blur.tag = 0x48474A;
        [bar insertSubview:state.blur atIndex:0];
    }
    [CATransaction begin]; [CATransaction setDisableActions:YES];
    for (UIView *child in bar.subviews.copy) {
        if (child == state.blur) continue;
        BOOL row = NO;
        for (UIView *button in child.subviews) if (HGIsClass(button, @"SSTabBarTextButton")) { row = YES; break; }
        if (row) {
            id color = objc_getAssociatedObject(child, &HGRowColorKey);
            if (active) {
                if (!color) objc_setAssociatedObject(child, &HGRowColorKey, child.layer.backgroundColor ? [UIColor colorWithCGColor:child.layer.backgroundColor] : NSNull.null, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
                if (child.layer.backgroundColor) child.layer.backgroundColor = nil;
            } else if (color) {
                child.layer.backgroundColor = [color isKindOfClass:UIColor.class] ? [(UIColor *)color CGColor] : nil;
                objc_setAssociatedObject(child, &HGRowColorKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
            }
        }
        BOOL paint = [child isKindOfClass:UIVisualEffectView.class] || [child isKindOfClass:UIImageView.class];
        if (paint && child.bounds.size.width >= bar.bounds.size.width * 0.85) {
            NSNumber *opacity = objc_getAssociatedObject(child, &HGOpacityKey);
            if (active) {
                if (!opacity) objc_setAssociatedObject(child, &HGOpacityKey, @(child.layer.opacity), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
                if (child.layer.opacity != 0) child.layer.opacity = 0;
            } else if (opacity) { child.layer.opacity = opacity.floatValue; objc_setAssociatedObject(child, &HGOpacityKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC); }
        }
    }
    if (active) {
        CGFloat h = HGBool(@"tab.layout.enabled") ? MIN(bar.bounds.size.height, HGNumber(@"tab.appearance.height")) : bar.bounds.size.height;
        CGRect rect = CGRectMake(0, bar.bounds.size.height - h, bar.bounds.size.width, h);
        if (bar.layer.backgroundColor) bar.layer.backgroundColor = nil;
        if (!CGRectEqualToRect(state.blur.frame, rect)) state.blur.frame = rect;
    } else {
        [state.blur removeFromSuperview]; state.blur = nil;
        bar.layer.backgroundColor = state.hostBackground.CGColor;
    }
    [CATransaction commit];
    for (UIView *child in bar.subviews) {
        if (HGIsClass(child, @"SSTabBarTextButton")) HGTabAppearanceCaption(child);
        else for (UIView *button in child.subviews) if (HGIsClass(button, @"SSTabBarTextButton")) HGTabAppearanceCaption(button);
    }
    if (liquid) HGLiquidTabLayout(bar);
}
void HGInstallTabAppearance(void) {
    HGHookLayout(@"SSTabBar", ^(UIView *bar) { HGAppearanceLayout(bar); });
    SEL moved = @selector(didMoveToWindow);
    HGInstall(NSClassFromString(@"SSTabBar"), moved, ^id(IMP original) {
        return ^(UIView *bar) { ((void (*)(id, SEL))original)(bar, moved); if (bar.window) { HGAppearanceLayout(bar); HGRefreshViews(); } else HGLiquidTabLayout(bar); };
    });
    SEL hidden = @selector(setHidden:);
    HGInstall(NSClassFromString(@"SSTabBar"), hidden, ^id(IMP original) {
        return ^(UIView *bar, BOOL value) { ((void (*)(id, SEL, BOOL))original)(bar, hidden, value); if (value) HGLiquidTabLayout(bar); else [bar setNeedsLayout]; };
    });
}


