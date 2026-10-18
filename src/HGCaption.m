#import "HGCore.h"
static char HGCaptionKey;
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
        HGHookLayout(name, ^(UIView *view) { HGCaptionFonts(view); HGApplyViewing(view); });
    SEL setter = @selector(setFont:);
    HGInstall(NSClassFromString(@"YYLabel"), setter, ^id(IMP original) {
        return ^(UIView *view, UIFont *font) {
            if (HGHandleCaptionFont(view, font, ^(UIFont *output) { ((void (*)(id, SEL, UIFont *))original)(view, setter, output); })) return;
            ((void (*)(id, SEL, UIFont *))original)(view, setter, font);
        };
    });
}

