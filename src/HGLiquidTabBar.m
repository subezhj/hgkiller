#import "HGCore.h"
static char HGLiquidKey, HGNativeProxyKey;
static UITabBar *HGSourceTabBar(UIView *host) {
    for (UIView *sibling in host.superview.subviews)
        if (HGIsClass(sibling, @"CYLTabBar") && [sibling isKindOfClass:UITabBar.class]) return (id)sibling;
    return nil;
}
static NSArray<UIView *> *HGTabButtons(UIView *root) {
    NSMutableArray *buttons = [NSMutableArray array];
    for (UIView *child in root.subviews) {
        if (child.tag == 0x484751 || child.tag == 0x484750) continue;
        if (HGIsClass(child, @"SSTabBarTextButton")) [buttons addObject:child];
        else [buttons addObjectsFromArray:HGTabButtons(child)];
    }
    [buttons sortUsingComparator:^NSComparisonResult(UIView *a, UIView *b) {
        CGFloat x = [a convertPoint:CGPointZero toView:root].x, y = [b convertPoint:CGPointZero toView:root].x;
        return x < y ? NSOrderedAscending : (x > y ? NSOrderedDescending : NSOrderedSame);
    }];
    return buttons;
}
@interface HGNativeTabProxy : NSObject <UITabBarDelegate>
@property(nonatomic, weak) UIView *host;
@end
@implementation HGNativeTabProxy
- (void)tabBar:(UITabBar *)tabBar didSelectItem:(UITabBarItem *)item {
    if (!HGEnabled() || !HGBool(@"tab.liquid.enabled")) return;
    NSArray *buttons = HGTabButtons(self.host); NSUInteger index = [tabBar.items indexOfObjectIdenticalTo:item];
    if (index >= buttons.count) return;
    UIView *button = buttons[index];
    if ([button isKindOfClass:UIControl.class]) {
        UIControl *control = (UIControl *)button;
        BOOL dispatched = NO;
        // Red Fruit has builds where actions are attached to a wrapper target
        // and the visible control does not advertise TouchUpInside. Re-send
        // every registered target/action through UIApplication as UIKit does
        // for a real touch.
        for (id target in control.allTargets) {
            for (NSString *name in [control actionsForTarget:target forControlEvent:UIControlEventTouchUpInside]) {
                SEL send = NSSelectorFromString(@"sendAction:to:from:forEvent:");
                if ([UIApplication.sharedApplication respondsToSelector:send])
                    dispatched = ((BOOL (*)(id, SEL, SEL, id, id, UIEvent *))objc_msgSend)(UIApplication.sharedApplication, send, NSSelectorFromString(name), target, control, nil) || dispatched;
            }
        }
        if (!dispatched) [control sendActionsForControlEvents:UIControlEventTouchUpInside];
    }
    else {
        UITabBar *source = HGSourceTabBar(self.host);
        if (index < source.items.count && [source.delegate respondsToSelector:@selector(tabBar:didSelectItem:)]) {
            source.selectedItem = source.items[index];
            [source.delegate tabBar:source didSelectItem:source.items[index]];
        }
    }
    for (UIResponder *next = self.host; next; next = next.nextResponder) {
        if ([next isKindOfClass:UITabBarController.class] || [NSStringFromClass(next.class) isEqualToString:@"SSTabBarController"]) {
            SEL setter = @selector(setSelectedIndex:);
            if ([next respondsToSelector:setter])
                ((void (*)(id, SEL, NSUInteger))objc_msgSend)(next, setter, index);
            break;
        }
    }
    [self.host setNeedsLayout];
}
@end
UITabBar *HGCreateNativeTabBar(UIView *host) {
    NSArray *buttons = HGTabButtons(host); if (buttons.count != 3) return nil;
    UITabBar *native = [[UITabBar alloc] initWithFrame:host.bounds]; native.tag = 0x484751;
    native.overrideUserInterfaceStyle = UIUserInterfaceStyleDark;
    // Leave appearance ownership to UIKit. On iOS 26 this is what enables the
    // standard liquid-glass tab bar platter; forcing a transparent appearance
    // produces only a dark/clear rectangle.
    // Do not assign standardAppearance/scrollEdgeAppearance here. iOS 26/27
    // decides whether to create the native Liquid Glass platter from the
    // system-owned UITabBar configuration.
    native.translucent = YES;
    NSArray *titles = @[@"首页", @"剧场", @"我的"], *symbols = @[@"house.fill", @"play.rectangle.fill", @"person.fill"];
    NSMutableArray *items = [NSMutableArray array];
    for (NSUInteger i = 0; i < 3; i++) {
        UITabBarItem *item = [[UITabBarItem alloc] initWithTitle:titles[i] image:[UIImage systemImageNamed:symbols[i]] tag:i];
        [items addObject:item];
    }
    native.items = items; native.selectedItem = items.firstObject;
    HGNativeTabProxy *proxy = [HGNativeTabProxy new]; proxy.host = host; native.delegate = proxy;
    // The visible SSTabBarTextButton instances may be gesture-backed and
    // expose no UIControl event flags. The proxy still has a route through the
    // SSTabBarController, so never disable the native hit target on that guess.
    native.userInteractionEnabled = YES;
    objc_setAssociatedObject(native, &HGNativeProxyKey, proxy, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    return native;
}
@interface HGLiquidPaint : NSObject
@property(nonatomic, weak) UIView *view;
@property(nonatomic) float opacity;
@property(nonatomic) BOOL interaction;
@property(nonatomic, strong) UIColor *background;
@end
@implementation HGLiquidPaint @end
@interface HGLiquidState : NSObject
@property(nonatomic, strong) UIView *black;
@property(nonatomic, strong) UIVisualEffectView *backdrop;
@property(nonatomic, strong) UITabBar *native;
@property(nonatomic, strong) NSMutableArray<HGLiquidPaint *> *paints;
@end
@implementation HGLiquidState @end
static NSString *HGLiquidStatus;
static void HGLiquidRemember(HGLiquidState *state, UIView *view) {
    for (HGLiquidPaint *paint in state.paints) if (paint.view == view) return;
    HGLiquidPaint *paint = [HGLiquidPaint new]; paint.view = view; paint.opacity = view.layer.opacity;
    paint.interaction = view.userInteractionEnabled;
    paint.background = view.layer.backgroundColor ? [UIColor colorWithCGColor:view.layer.backgroundColor] : nil;
    [state.paints addObject:paint];
}
static void HGLiquidClean(HGLiquidState *state, UIView *root, BOOL hostBar) {
    if (root == state.black || root == state.native || root == state.backdrop) return;
    BOOL row = NO;
    for (UIView *child in root.subviews) if (HGIsClass(child, @"SSTabBarTextButton")) row = YES;
    if (hostBar || row) { HGLiquidRemember(state, root); if (root.layer.backgroundColor) root.layer.backgroundColor = nil; }
    for (UIView *child in root.subviews.copy) {
        if (child == state.black || child == state.native || child == state.backdrop) continue;
        if (state.native && (HGIsClass(child, @"SSTabBarTextButton") || (HGIsClass(root, @"CYLTabBar") && [child isKindOfClass:UIControl.class]))) {
            HGLiquidRemember(state, child);
            if (child.layer.opacity != 0) child.layer.opacity = 0;
            if (child.userInteractionEnabled) child.userInteractionEnabled = NO;
            continue;
        }
        BOOL backdrop = [child isKindOfClass:UIVisualEffectView.class] || [child isKindOfClass:UIImageView.class] ||
            [NSStringFromClass(child.class) containsString:@"BarBackground"];
        if (backdrop && child.bounds.size.width >= root.bounds.size.width * 0.85 && child.bounds.size.width > 100) {
            HGLiquidRemember(state, child); if (child.layer.opacity != 0) child.layer.opacity = 0;
        } else if (![child isKindOfClass:UIControl.class]) HGLiquidClean(state, child, NO);
    }
}
static BOOL HGHasSystemPlatter(UIView *view) {
    if ([NSStringFromClass(view.class) containsString:@"TabBarItemPlatter"]) return YES;
    for (UIView *child in view.subviews) if (HGHasSystemPlatter(child)) return YES;
    return NO;
}
static void HGSyncNativeTab(HGLiquidState *state, UIView *host) {
    UITabBar *native = state.native; if (!native) return;
    UITabBar *source = HGSourceTabBar(host); UIViewController *owner = HGOwner(host);
    NSUInteger selected = NSNotFound;
    if ([owner isKindOfClass:UITabBarController.class]) selected = ((UITabBarController *)owner).selectedIndex;
    else if (source.selectedItem) selected = [source.items indexOfObjectIdenticalTo:source.selectedItem];
    else {
        NSArray *buttons = HGTabButtons(host);
        for (NSUInteger i = 0; i < buttons.count; i++) if ([buttons[i] isKindOfClass:UIControl.class] && ((UIControl *)buttons[i]).selected) { selected = i; break; }
    }
    if (selected < native.items.count && native.selectedItem != native.items[selected]) native.selectedItem = native.items[selected];
    CGFloat scale = HGNumber(@"tab.textScale");
    UIFont *font = fabs(scale - 1) < 0.001 ? nil : [UIFont systemFontOfSize:MAX(9, 11 * scale) weight:UIFontWeightMedium];
    for (NSUInteger i = 0; i < native.items.count; i++) {
        UITabBarItem *item = native.items[i]; UIFont *current = [item titleTextAttributesForState:UIControlStateNormal][NSFontAttributeName];
        if (font ? ![current isEqual:font] : current != nil) {
            for (NSNumber *number in @[@(UIControlStateNormal), @(UIControlStateSelected)]) {
                UIControlState controlState = number.unsignedIntegerValue;
                NSMutableDictionary *attributes = [[item titleTextAttributesForState:controlState] mutableCopy] ?: [NSMutableDictionary dictionary];
                if (font) attributes[NSFontAttributeName] = font; else [attributes removeObjectForKey:NSFontAttributeName];
                [item setTitleTextAttributes:attributes forState:controlState];
            }
        }
        NSString *badge = i < source.items.count ? source.items[i].badgeValue : nil;
        if (item.badgeValue != badge && ![item.badgeValue isEqualToString:badge]) item.badgeValue = badge;
    }
    if (!CGRectEqualToRect(native.frame, host.bounds)) native.frame = host.bounds;
    if (host.subviews.lastObject != native) [host bringSubviewToFront:native];
}
void HGLiquidTabLayout(UIView *bar) {
    HGLiquidState *state = objc_getAssociatedObject(bar, &HGLiquidKey);
    BOOL on = HGEnabled() && HGBool(@"tab.liquid.enabled") && HGPlaybackVisible(bar) && bar.window.windowLevel == UIWindowLevelNormal &&
        (bar.window.bounds.size.height > bar.window.bounds.size.width || UIDevice.currentDevice.userInterfaceIdiom == UIUserInterfaceIdiomPad);
    if (!on) {
        HGRestoreVideoExperimentForBar(bar); if (!state) return;
        for (HGLiquidPaint *paint in state.paints) {
            paint.view.layer.opacity = paint.opacity; paint.view.layer.backgroundColor = paint.background.CGColor;
            paint.view.userInteractionEnabled = paint.interaction;
        }
        [state.black removeFromSuperview]; [state.backdrop removeFromSuperview]; [state.native removeFromSuperview];
        objc_setAssociatedObject(bar, &HGLiquidKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        if (!HGEnabled() || !HGBool(@"tab.liquid.enabled")) HGLiquidStatus = @"液态玻璃底栏未启用。";
        return;
    }
    if (!state) {
        state = [HGLiquidState new]; state.paints = [NSMutableArray array];
        state.black = [UIView new]; state.black.backgroundColor = UIColor.blackColor;
        state.black.userInteractionEnabled = NO; state.black.accessibilityElementsHidden = YES; state.black.tag = 0x484750;
        UIBlurEffect *blur = [UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemMaterialDark];
        state.backdrop = [[UIVisualEffectView alloc] initWithEffect:blur];
        state.backdrop.userInteractionEnabled = NO; state.backdrop.layer.cornerRadius = 30;
        state.backdrop.layer.cornerCurve = kCACornerCurveContinuous;
        state.backdrop.clipsToBounds = YES;
        state.backdrop.tag = 0x484752;
        state.native = HGCreateNativeTabBar(bar);
        objc_setAssociatedObject(bar, &HGLiquidKey, state, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        [bar insertSubview:state.black atIndex:0]; [bar addSubview:state.backdrop]; if (state.native) [bar addSubview:state.native];
    }
    HGSyncNativeTab(state, bar); HGLiquidClean(state, bar, YES);
    for (UIView *sibling in bar.superview.subviews) {
        if (sibling != bar && (HGIsClass(sibling, @"CYLTabBar") || HGIsClass(sibling, @"SSTabBar"))) {
            HGLiquidClean(state, sibling, YES);
            // Keep the host's controls in the responder tree for forwarding,
            // but remove their second visible tab layer entirely.
            HGLiquidRemember(state, sibling);
            sibling.layer.opacity = 0;
        }
    }
    if (state.native) HGUpdateVideoExperiment(bar); else HGRestoreVideoExperiment();
    BOOL covered = state.native && HGVideoCoversBar(bar);
    // The fallback black view used to cover the blur whenever the video did
    // not extend under the bar. Keep it hidden in liquid mode; the fallback is
    // the floating material capsule, not a black rectangle.
    if (!state.black.hidden) state.black.hidden = YES;
    if (!CGRectEqualToRect(state.black.frame, bar.bounds)) state.black.frame = bar.bounds;
    // Keep the hit-test bar on the app's original 84pt slot. Extend only the
    // visual material upward to meet the native progress track at y=784.
    BOOL hasPlatter = state.native && HGHasSystemPlatter(state.native);
    state.backdrop.hidden = hasPlatter;
    CGRect materialFrame = CGRectInset(bar.bounds, 10, 5);
    if (!CGRectEqualToRect(state.backdrop.frame, materialFrame)) state.backdrop.frame = materialFrame;
    if (state.native && !CGRectEqualToRect(state.native.frame, bar.bounds)) state.native.frame = bar.bounds;
    NSString *material = state.native ? (HGHasSystemPlatter(state.native) ? @"系统 UITabBar 悬浮布局已生成" : @"系统 UITabBar，等待/未生成 iOS 26 悬浮布局") : @"系统材质或原生切页事件不可用，保留黑色原生底栏";
    HGLiquidStatus = [NSString stringWithFormat:@"%@\n底栏背景：%@\n%@", material, covered ? @"实时视频" : @"黑色回退", HGVideoExperimentStatus()];
}
NSString *HGLiquidDiagnosticText(void) { return HGLiquidStatus ?: @"液态玻璃底栏尚未启用。"; }
