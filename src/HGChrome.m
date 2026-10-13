#import "HGCore.h"
#import "HGGeometry.h"

static char HGRightStateKey, HGFontStateKey;
static BOOL HGInVideoControls(UIView *view) {
    if (!view.window || view.window.windowLevel != UIWindowLevelNormal || view.window.bounds.size.width > view.window.bounds.size.height) return NO;
    for (UIView *node = view; node; node = node.superview)
        if (HGIsClass(node.nextResponder, @"FQVShortVideoListViewController")) return YES;
    return HGIsFeedView(view);
}
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
@property(nonatomic, strong) NSAttributedString *hostText;
@property(nonatomic, strong) NSAttributedString *appliedText;
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
    return state.hostHidden || (HGEnabled() && HGInVideoControls(view) && !HGBool(HGRightKey(view)));
}
static CGRect HGRightTargetFrame(UIView *item, CGRect host) {
    UIView *container = item.superview;
    if (!HGEnabled() || !HGInVideoControls(item) || !HGIsClass(container, @"SSShortVideoRightInteractionView")) return host;
    NSArray *items = HGRightItems(container);
    CGFloat total = 0, gap = HGNumber(@"right.gap"), scale = HGNumber(@"right.scale");
    NSUInteger visible = 0; UIView *last = nil;
    for (UIView *view in items) if (!HGRightHidden(view)) {
        total += MAX(44.0, HGHostFrame(view).size.height * scale + gap);
        visible++; last = view;
    }
    if (visible) total += HGHostFrame(last).size.height - MAX(44.0, HGHostFrame(last).size.height * scale + gap);
    CGFloat y = MAX(0.0, CGRectGetHeight(container.bounds) - total);
    for (UIView *view in items) {
        if (HGRightHidden(view)) continue;
        if (view == item) { host.origin.y = y; break; }
        y += MAX(44.0, HGHostFrame(view).size.height * scale + gap);
    }
    return host;
}
static void HGApplyRightItem(UIView *item) {
    HGRightState *state = HGRightStateFor(item);
    BOOL active = HGEnabled() && HGInVideoControls(item);
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
static NSAttributedString *HGHeaderText(HGFontState *state, NSAttributedString *text, BOOL active) {
    if (!text) { state.hostText = nil; state.appliedText = nil; return nil; }
    if (![text isEqualToAttributedString:state.appliedText]) state.hostText = [text copy];
    if (!active) { state.appliedText = nil; return state.hostText; }
    NSMutableAttributedString *result = [state.hostText mutableCopy];
    [state.hostText enumerateAttribute:NSFontAttributeName inRange:NSMakeRange(0, state.hostText.length) options:0 usingBlock:^(id font, NSRange range, BOOL *stop) {
        if ([font isKindOfClass:UIFont.class]) [result addAttribute:NSFontAttributeName value:[font fontWithSize:MAX(10, [font pointSize] * HGNumber(@"top.scale"))] range:range];
    }];
    state.appliedText = result; return result;
}
static void HGScaleHeaderFonts(UIView *root) {
    if ([root isKindOfClass:UILabel.class]) {
        UILabel *label = (id)root;
        HGFontState *state = objc_getAssociatedObject(label, &HGFontStateKey);
        BOOL active = HGEnabled() && HGBool(@"top.enabled") && HGInHeader(root) && root.window != nil;
        if (!state && active) {
            state = [HGFontState new]; state.host = label.font;
            objc_setAssociatedObject(label, &HGFontStateKey, state, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        }
        if (state) {
            if (!state.applied || ![label.font isEqual:state.applied]) state.host = label.font;
            UIFont *font = active ? [state.host fontWithSize:MAX(10, state.host.pointSize * HGNumber(@"top.scale"))] : state.host;
            if (![label.font isEqual:font]) HGApply(^{ label.font = font; });
            state.applied = active ? font : nil;
            NSAttributedString *text = HGHeaderText(state, label.attributedText, active);
            if (text && ![text isEqualToAttributedString:label.attributedText]) HGApply(^{ label.attributedText = text; });
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
    SEL hitSelector = @selector(hitTest:withEvent:);
    HGInstall(NSClassFromString(@"SSShortVideoRightInteractionView"), hitSelector, ^id(IMP original) {
        return ^UIView *(UIView *container, CGPoint point, UIEvent *event) {
            if (HGEnabled() && HGInVideoControls(container) && !container.hidden && container.alpha > 0.01 && container.userInteractionEnabled && [container pointInside:point withEvent:event]) {
                UIView *nearest = nil; CGFloat distance = CGFLOAT_MAX;
                for (UIView *item in HGRightItems(container)) if (!HGRightHidden(item) && item.userInteractionEnabled && item.alpha > 0.01) {
                    CGFloat d = fabs(point.y - CGRectGetMidY(item.frame));
                    if (d < distance) { nearest = item; distance = d; }
                }
                if (nearest && distance <= CGRectGetHeight(nearest.bounds) / 2)
                    return [nearest hitTest:[nearest convertPoint:point fromView:container] withEvent:event];
            }
            return ((UIView *(*)(id, SEL, CGPoint, UIEvent *))original)(container, hitSelector, point, event);
        };
    });
    SEL fontSelector = @selector(setFont:);
    HGInstall(UILabel.class, fontSelector, ^id(IMP original) {
        return ^(UILabel *label, UIFont *font) {
            UIFont *output = font;
            if (!HGIsApplying() && font && HGInHeader(label)) {
                HGFontState *state = objc_getAssociatedObject(label, &HGFontStateKey);
                if (!state) { state = [HGFontState new]; objc_setAssociatedObject(label, &HGFontStateKey, state, OBJC_ASSOCIATION_RETAIN_NONATOMIC); }
                if (![font isEqual:state.applied]) state.host = font;
                BOOL active = HGEnabled() && HGBool(@"top.enabled");
                output = active ? [state.host fontWithSize:MAX(10, state.host.pointSize * HGNumber(@"top.scale"))] : state.host;
                state.applied = active ? output : nil;
            }
            ((void (*)(id, SEL, UIFont *))original)(label, fontSelector, output);
        };
    });
    SEL attributedSelector = @selector(setAttributedText:);
    HGInstall(UILabel.class, attributedSelector, ^id(IMP original) {
        return ^(UILabel *label, NSAttributedString *text) {
            NSAttributedString *output = text;
            if (!HGIsApplying() && HGInHeader(label)) {
                HGFontState *state = objc_getAssociatedObject(label, &HGFontStateKey);
                if (!state) { state = [HGFontState new]; state.host = label.font; objc_setAssociatedObject(label, &HGFontStateKey, state, OBJC_ASSOCIATION_RETAIN_NONATOMIC); }
                output = HGHeaderText(state, text, HGEnabled() && HGBool(@"top.enabled"));
            }
            ((void (*)(id, SEL, NSAttributedString *))original)(label, attributedSelector, output);
        };
    });
    HGHookLayout(@"SSHGBookStoreCategoryTitleCell", ^(UIView *view) { if (HGInHeader(view)) HGScaleHeaderFonts(view); });
    HGHookLayout(@"SSVideoSeriesFeedHeaderView", ^(UIView *view) { HGScaleHeaderFonts(view); });
    HGHookLayout(@"FQRJXCategoryCollectionView", ^(UIView *view) { if (HGInHeader(view)) HGScaleHeaderFonts(view); });
}



