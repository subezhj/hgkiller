#import "HGCore.h"
static char HGCaptionKey;
static char HGCaptionGeometryKey;
@interface HGCaptionGeometry : NSObject
@property(nonatomic) CGRect host;
@property(nonatomic) CGRect applied;
@property(nonatomic) BOOL active;
@end
@implementation HGCaptionGeometry @end
static void HGCaptionRepair(UIView *container) {
    BOOL on = HGEnabled() && HGBool(HGViewingKey(container, @"caption.enabled"));
    CGFloat descriptionY = CGFLOAT_MAX;
    for (UIView *row in container.subviews)
        if (!row.hidden && ([row isKindOfClass:UIScrollView.class] || HGIsClass(row, @"YYLabel")) && row.bounds.size.height > 1)
            descriptionY = MIN(descriptionY, row.frame.origin.y);
    CGFloat distributionY = CGFLOAT_MAX;
    for (UIView *ancestor = container; ancestor && ancestor.superview; ancestor = ancestor.superview) {
        for (UIView *sibling in ancestor.superview.subviews) {
            UIView *entry = HGFindView(sibling, @"SSShortVideoBottomDistributionView");
            if (entry) {
                CGRect rect = [entry convertRect:entry.bounds toView:container];
                distributionY = MIN(distributionY, rect.origin.y);
            }
        }
    }
    for (UIView *row in container.subviews) {
        HGCaptionGeometry *state = objc_getAssociatedObject(row, &HGCaptionGeometryKey);
        if (!on) {
            if (state.active && CGRectEqualToRect(row.frame, state.applied)) row.frame = state.host;
            objc_setAssociatedObject(row, &HGCaptionGeometryKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC); continue;
        }
        if (row.hidden || row.class != UIView.class || row.bounds.size.width < container.bounds.size.width * 0.8 || row.bounds.size.height < 16 || row.bounds.size.height > 32) continue;
        BOOL label = NO, icon = NO;
        for (UIView *child in row.subviews) { if ([child isKindOfClass:UILabel.class] && child.bounds.size.width > 1) label = YES; if ([child isKindOfClass:UIImageView.class]) icon = YES; }
        if (!label || !icon || descriptionY == CGFLOAT_MAX) continue;
        if (!state) { state = [HGCaptionGeometry new]; objc_setAssociatedObject(row, &HGCaptionGeometryKey, state, OBJC_ASSOCIATION_RETAIN_NONATOMIC); }
        if (!state.active || !CGRectEqualToRect(row.frame, state.applied)) state.host = row.frame;
        CGRect target = state.host;
        CGFloat maximum = MAX(0, MIN(descriptionY - target.size.height - 8, container.bounds.size.height - target.size.height));
        if (distributionY != CGFLOAT_MAX)
            maximum = MAX(0, MIN(maximum, distributionY - target.size.height - 8));
        target.origin.y = MIN(target.origin.y, maximum);
        state.applied = target; state.active = !CGRectEqualToRect(target, state.host);
        if (!CGRectEqualToRect(row.frame, target)) HGApply(^{ row.frame = target; });
    }
}
@interface HGCaptionState : NSObject
@property(nonatomic, strong) UIFont *host;
@property(nonatomic, strong) UIFont *applied;
@end
@implementation HGCaptionState @end
static NSString *HGCaptionRole(UIView *view) {
    for (UIView *node = view; node; node = node.superview) {
        if (HGIsClass(node, @"FQVTagListView") || HGIsClass(node, @"SSShortVideoHotCommentView")) return nil;
        if (HGIsClass(node, @"SSShortVideoOutterSeriesLeftContainerView") || HGIsClass(node, @"SSShortVideoSingleSeriesInfoLeftContainerView")) {
            CGRect rect = [view convertRect:view.bounds toView:node];
            BOOL description = HGIsClass(view, @"YYLabel") || rect.origin.y >= 50 || ([view isKindOfClass:UILabel.class] && [((UILabel *)view).text isEqualToString:@"展开"]);
            return description ? @"caption.descriptionScale" : @"caption.titleScale";
        }
    }
    return nil;
}
BOOL HGHandleCaptionFont(UIView *view, UIFont *font, void (^apply)(UIFont *)) {
    NSString *key = HGCaptionRole(view);
    if (!key || HGIsApplying() || !font) return NO;
    HGCaptionState *state = objc_getAssociatedObject(view, &HGCaptionKey);
    if (!state) { state = [HGCaptionState new]; objc_setAssociatedObject(view, &HGCaptionKey, state, OBJC_ASSOCIATION_RETAIN_NONATOMIC); }
    if (![font isEqual:state.applied]) state.host = font;
    BOOL active = HGEnabled() && HGBool(HGViewingKey(view, @"caption.enabled"));
    UIFont *output = active ? [state.host fontWithSize:MAX(9, state.host.pointSize * HGNumber(HGViewingKey(view, key)))] : state.host;
    state.applied = active ? output : nil;
    UIFont *current = ((UIFont *(*)(id, SEL))objc_msgSend)(view, @selector(font));
    if (![current isEqual:output]) apply(output);
    return YES;
}
static void HGCaptionFonts(UIView *view) {
    if (([view isKindOfClass:UILabel.class] || HGIsClass(view, @"YYLabel")) && [view respondsToSelector:@selector(font)]) {
        UIFont *font = ((UIFont *(*)(id, SEL))objc_msgSend)(view, @selector(font));
        HGHandleCaptionFont(view, font, ^(UIFont *output) { HGApply(^{ ((void (*)(id, SEL, UIFont *))objc_msgSend)(view, @selector(setFont:), output); }); });
    }
    for (UIView *child in view.subviews) HGCaptionFonts(child);
}
void HGInstallCaption(void) {
    for (NSString *name in @[@"SSShortVideoOutterSeriesLeftContainerView", @"SSShortVideoSingleSeriesInfoLeftContainerView"])
        HGHookLayout(name, ^(UIView *view) { HGCaptionRepair(view); HGCaptionFonts(view); HGApplyViewing(view); });
    SEL setter = @selector(setFont:);
    // Red Fruit uses YYLabel for some descriptions, but the title/"展开"
    // controls are ordinary UILabels on several player variants. Hook both
    // classes so a later host font reset cannot silently undo the slider.
    for (Class labelClass in @[NSClassFromString(@"YYLabel"), UILabel.class]) {
        if (!labelClass) continue;
        HGInstall(labelClass, setter, ^id(IMP original) {
        return ^(UIView *view, UIFont *font) {
            if (HGHandleCaptionFont(view, font, ^(UIFont *output) { ((void (*)(id, SEL, UIFont *))original)(view, setter, output); })) return;
            ((void (*)(id, SEL, UIFont *))original)(view, setter, font);
        };
        });
    }
}

