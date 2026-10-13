#import "HGCore.h"
#import "HGGeometry.h"
#import <limits.h>

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
@property(nonatomic) BOOL hostClips;
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
        state.hostHidden = view.hidden; state.hostClips = view.layer.masksToBounds;
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
static CGPoint HGRightVisualCenter(UIView *item) {
    UIView *container = item.superview;
    CGFloat scale = HGNumber(@"right.scale"), gap = HGNumber(@"right.gap"), total = 0;
    NSArray *items = HGRightItems(container);
    for (UIView *view in items) if (!HGRightHidden(view)) total += view.bounds.size.height * scale + gap;
    total = MAX(0, total - gap);
    CGFloat y = MAX(0, container.bounds.size.height - total);
    for (UIView *view in items) {
        if (HGRightHidden(view)) continue;
        CGFloat h = view.bounds.size.height * scale;
        if (view == item) return CGPointMake(CGRectGetMidX(item.frame), y + h / 2);
        y += h + gap;
    }
    return item.center;
}
static void HGApplyRightItem(UIView *item) {
    HGRightState *state = HGRightStateFor(item);
    BOOL active = HGEnabled() && HGInVideoControls(item);
    BOOL hidden = HGRightHidden(item);
    if (item.hidden != hidden) HGApply(^{ item.hidden = hidden; });
    if (state.scaled && !CATransform3DEqualToTransform(item.layer.sublayerTransform, state.appliedSublayers)) {
        state.hostSublayers = item.layer.sublayerTransform;
    }
    CATransform3D target = state.hostSublayers;
    if (active) {
        CGPoint center = HGRightVisualCenter(item);
        target = CATransform3DConcat(state.hostSublayers, CATransform3DMakeScale(HGNumber(@"right.scale"), HGNumber(@"right.scale"), 1));
        target.m41 += center.x - item.center.x;
        target.m42 += center.y - item.center.y;
    }
    // Scale pixels inside the unchanged hit-test view. Never reset UIView.transform or bounds in layout.
    [CATransaction begin]; [CATransaction setDisableActions:YES];
    if (!CATransform3DEqualToTransform(item.layer.sublayerTransform, target)) {
        HGApply(^{ item.layer.sublayerTransform = target; });
    }
    [CATransaction commit];
    state.appliedSublayers = target;
    state.scaled = active;
    HGApply(^{ if (item.layer.masksToBounds != (active ? NO : state.hostClips)) item.layer.masksToBounds = active ? NO : state.hostClips; });
}
static NSHashTable<UIView *> *HGRightContainers;
static void HGTrackRight(UIView *container) {
    if (!HGRightContainers) HGRightContainers = [NSHashTable weakObjectsHashTable];
    [HGRightContainers addObject:container];
    for (UIView *item in HGRightItems(container)) HGApplyRightItem(item);
}
static void HGFindRightContainers(UIView *root) {
    if (HGIsClass(root, @"SSShortVideoRightInteractionView")) { HGTrackRight(root); return; }
    for (UIView *child in root.subviews) HGFindRightContainers(child);
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
            if (!state.hostText && (!state.applied || ![label.font isEqual:state.applied])) state.host = label.font;
            UIFont *font = active ? [state.host fontWithSize:MAX(10, state.host.pointSize * HGNumber(@"top.scale"))] : state.host;
            if (!state.hostText && ![label.font isEqual:font]) HGApply(^{ label.font = font; });
            state.applied = active ? font : nil;
            NSAttributedString *text = state.hostText ? HGHeaderText(state, label.attributedText, active) : nil;
            if (text && ![text isEqualToAttributedString:label.attributedText]) HGApply(^{ label.attributedText = text; });
        }
    }
    for (UIView *child in root.subviews) HGScaleHeaderFonts(child);
}
void HGInstallChrome(void) {
    HGHookLayout(@"SSShortVideoRightInteractionView", ^(UIView *container) {
        HGTrackRight(container);
    });
    HGHookControllerLayout(@"FQVShortVideoListViewController", ^(UIViewController *controller) { HGFindRightContainers(controller.view); });
    SEL moved = @selector(didMoveToWindow);
    HGInstall(NSClassFromString(@"SSShortVideoRightInteractionView"), moved, ^id(IMP original) {
        return ^(UIView *container) { ((void (*)(id, SEL))original)(container, moved); HGTrackRight(container); };
    });
    CFRunLoopObserverRef observer = CFRunLoopObserverCreateWithHandler(kCFAllocatorDefault, kCFRunLoopBeforeWaiting, true, LONG_MAX, ^(CFRunLoopObserverRef observer, CFRunLoopActivity activity) {
        for (UIView *container in HGRightContainers.allObjects) if (container.window)
            HGApply(^{ for (UIView *item in HGRightItems(container)) HGApplyRightItem(item); });
    });
    CFRunLoopAddObserver(CFRunLoopGetMain(), observer, kCFRunLoopCommonModes); CFRelease(observer);
    for (NSString *name in HGRightClasses()) {
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
                    CGFloat d = fabs(point.y - HGRightVisualCenter(item).y);
                    if (d < distance) { nearest = item; distance = d; }
                }
                if (nearest && distance <= CGRectGetHeight(nearest.bounds) / 2)
                                    {
                    CGPoint visual = HGRightVisualCenter(nearest);
                    CGPoint local = CGPointMake(nearest.bounds.size.width / 2 + point.x - visual.x, nearest.bounds.size.height / 2 + point.y - visual.y);
                    return [nearest hitTest:local withEvent:event] ?: nearest;
                }
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
    SEL textSelector = @selector(setText:);
    HGInstall(UILabel.class, textSelector, ^id(IMP original) {
        return ^(UILabel *label, NSString *text) {
            if (!HGIsApplying()) {
                HGFontState *state = objc_getAssociatedObject(label, &HGFontStateKey);
                state.hostText = nil; state.appliedText = nil;
            }
            ((void (*)(id, SEL, NSString *))original)(label, textSelector, text);
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







