#import "HGCore.h"
static char HGLiquidKey;
@interface HGLiquidPaint : NSObject
@property(nonatomic, weak) UIView *view;
@property(nonatomic) float opacity;
@property(nonatomic, strong) UIColor *background;
@end
@implementation HGLiquidPaint @end
@interface HGLiquidState : NSObject
@property(nonatomic, strong) UIView *black;
@property(nonatomic, strong) UIVisualEffectView *glass;
@property(nonatomic, strong) NSMutableArray<HGLiquidPaint *> *paints;
@end
@implementation HGLiquidState @end
static NSString *HGLiquidStatus;
static UIVisualEffect *HGMakeLiquidEffect(void) {
    Class cls = NSClassFromString(@"UIGlassEffect"); SEL make = NSSelectorFromString(@"effectWithStyle:");
    if (!cls || ![cls respondsToSelector:make]) return nil;
    id effect = ((id (*)(id, SEL, NSInteger))objc_msgSend)(cls, make, 0); // UIGlassEffectStyleRegular
    if (![effect isKindOfClass:UIVisualEffect.class]) return nil;
    SEL interactive = NSSelectorFromString(@"setInteractive:");
    if ([effect respondsToSelector:interactive]) ((void (*)(id, SEL, BOOL))objc_msgSend)(effect, interactive, NO);
    return effect;
}
static void HGLiquidRemember(HGLiquidState *state, UIView *view) {
    for (HGLiquidPaint *paint in state.paints) if (paint.view == view) return;
    HGLiquidPaint *paint = [HGLiquidPaint new]; paint.view = view; paint.opacity = view.layer.opacity;
    paint.background = view.layer.backgroundColor ? [UIColor colorWithCGColor:view.layer.backgroundColor] : nil;
    [state.paints addObject:paint];
}
static void HGLiquidClean(HGLiquidState *state, UIView *root, BOOL hostBar) {
    if (root == state.black || root == state.glass) return;
    BOOL row = NO;
    for (UIView *child in root.subviews) if (HGIsClass(child, @"SSTabBarTextButton")) row = YES;
    if (hostBar || row) {
        HGLiquidRemember(state, root);
        if (root.layer.backgroundColor) root.layer.backgroundColor = nil;
    }
    for (UIView *child in root.subviews.copy) {
        if (child == state.black || child == state.glass) continue;
        BOOL backdrop = [child isKindOfClass:UIVisualEffectView.class] || [child isKindOfClass:UIImageView.class] ||
            [NSStringFromClass(child.class) containsString:@"BarBackground"];
        if (backdrop && child.bounds.size.width >= root.bounds.size.width * 0.85 && child.bounds.size.width > 100) {
            HGLiquidRemember(state, child);
            if (child.layer.opacity != 0) child.layer.opacity = 0;
        } else if (![child isKindOfClass:UIControl.class]) HGLiquidClean(state, child, NO);
    }
}
void HGLiquidTabLayout(UIView *bar) {
    HGLiquidState *state = objc_getAssociatedObject(bar, &HGLiquidKey);
    BOOL on = HGEnabled() && HGBool(@"tab.liquid.enabled") && HGPlaybackVisible(bar) && bar.window.windowLevel == UIWindowLevelNormal && bar.window.bounds.size.height > bar.window.bounds.size.width;
    if (!on) {
        HGRestoreVideoExperimentForBar(bar);
        if (!state) return;
        for (HGLiquidPaint *paint in state.paints) {
            paint.view.layer.opacity = paint.opacity;
            paint.view.layer.backgroundColor = paint.background.CGColor;
        }
        [state.black removeFromSuperview]; [state.glass removeFromSuperview];
        objc_setAssociatedObject(bar, &HGLiquidKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        if (!HGEnabled() || !HGBool(@"tab.liquid.enabled")) HGLiquidStatus = @"液态玻璃底栏未启用。";
        return; // Keep the last playback diagnostic when entering settings hides the bar.
    }
    if (!state) {
        state = [HGLiquidState new]; state.paints = [NSMutableArray array];
        state.black = [UIView new]; state.black.backgroundColor = UIColor.blackColor;
        state.black.userInteractionEnabled = NO; state.black.accessibilityElementsHidden = YES; state.black.tag = 0x484750;
        UIVisualEffect *effect = HGMakeLiquidEffect();
        if (effect) {
            state.glass = [[UIVisualEffectView alloc] initWithEffect:effect];
            state.glass.overrideUserInterfaceStyle = UIUserInterfaceStyleDark;
            state.glass.userInteractionEnabled = NO; state.glass.accessibilityElementsHidden = YES;
            state.glass.layer.cornerRadius = 25; state.glass.clipsToBounds = YES; state.glass.tag = 0x484751;
        }
        objc_setAssociatedObject(bar, &HGLiquidKey, state, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        [bar insertSubview:state.black atIndex:0];
        if (state.glass) [bar insertSubview:state.glass aboveSubview:state.black];
    }
    HGLiquidClean(state, bar, YES);
    for (UIView *sibling in bar.superview.subviews)
        if (HGIsClass(sibling, @"CYLTabBar")) HGLiquidClean(state, sibling, YES);
    if (state.glass) HGUpdateVideoExperiment(bar); else HGRestoreVideoExperiment();
    BOOL covered = state.glass && HGVideoCoversBar(bar);
    if (state.black.hidden != covered) state.black.hidden = covered;
    if (!CGRectEqualToRect(state.black.frame, bar.bounds)) state.black.frame = bar.bounds;
    CGFloat height = MIN(50, MAX(0, bar.bounds.size.height - bar.window.safeAreaInsets.bottom));
    CGRect capsule = CGRectMake(12, 0, MAX(0, bar.bounds.size.width - 24), height);
    if (state.glass && !CGRectEqualToRect(state.glass.frame, capsule)) state.glass.frame = capsule;
    HGLiquidStatus = [NSString stringWithFormat:@"系统玻璃：%@\n底栏背景：%@\n%@", state.glass ? @"UIGlassEffect Regular" : @"不可用，黑色原生底栏", covered ? @"实时视频" : @"黑色回退", HGVideoExperimentStatus()];
}
NSString *HGLiquidDiagnosticText(void) { return HGLiquidStatus ?: @"液态玻璃底栏尚未启用。"; }
