#import "HGCore.h"
#import "HGGeometry.h"
#import <limits.h>

extern BOOL HGHandleTabFont(UILabel *label, UIFont *font, void (^apply)(UIFont *));
static char HGRightStateKey, HGFontStateKey;
static NSUInteger HGNativeRightLayoutDepth;
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
@property(nonatomic) CGAffineTransform hostTransform;
@property(nonatomic) CGRect nativeFrame;
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
        state.hostTransform = view.transform; state.nativeFrame = view.frame;
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
        if (view == item) return CGPointMake(CGRectGetMidX(HGRightStateFor(item).nativeFrame), y + h / 2);
        y += h + gap;
    }
    return item.center;
}
static void HGApplyRightItem(UIView *item) {
    HGRightState *state = HGRightStateFor(item);
    BOOL active = HGEnabled() && HGInVideoControls(item);
    BOOL hidden = HGRightHidden(item);
    if (item.hidden != hidden) HGApply(^{ item.hidden = hidden; });
    if (!state.scaled) state.nativeFrame = item.frame;
    CGPoint center = active ? HGRightVisualCenter(item) : CGPointMake(CGRectGetMidX(state.nativeFrame), CGRectGetMidY(state.nativeFrame));
    CGAffineTransform target = state.hostTransform;
    if (active) {
        CGFloat scale = HGNumber(@"right.scale");
        target = CGAffineTransformConcat(state.hostTransform, CGAffineTransformMake(scale, 0, 0, scale,
            center.x - CGRectGetMidX(state.nativeFrame), center.y - CGRectGetMidY(state.nativeFrame)));
    }
    [CATransaction begin]; [CATransaction setDisableActions:YES];
    HGApply(^{
        if (!CGAffineTransformEqualToTransform(item.transform, target)) item.transform = target;
        // Every pixel and its gesture/UIControl now share UIKit's coordinate transform.
        if (!CATransform3DEqualToTransform(item.layer.sublayerTransform, state.hostSublayers)) item.layer.sublayerTransform = state.hostSublayers;
    });
    [CATransaction commit];
    state.scaled = active;
}
static void HGRestoreRightTransform(UIView *item) {
    HGRightState *state = objc_getAssociatedObject(item, &HGRightStateKey);
    if (!state || !state.scaled) return;
    HGApply(^{ item.transform = state.hostTransform; });
    state.scaled = NO;
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
    SEL layout = @selector(layoutSubviews);
    HGInstall(NSClassFromString(@"SSShortVideoRightInteractionView"), layout, ^id(IMP original) {
        return ^(UIView *container) {
            HGNativeRightLayoutDepth++;
            @try { ((void (*)(id, SEL))original)(container, layout); } @finally { HGNativeRightLayoutDepth--; }
            HGTrackRight(container);
        };
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
        SEL frameSelector = @selector(setFrame:);
        HGInstall(NSClassFromString(name), frameSelector, ^id(IMP original) {
            return ^(UIView *item, CGRect frame) {
                HGRightState *state = HGRightStateFor(item);
                if (!HGIsApplying() && state.scaled && fabs(frame.origin.x - state.nativeFrame.origin.x) < 0.05 && fabs(frame.origin.y - state.nativeFrame.origin.y) < 0.05 && fabs(frame.size.width - state.nativeFrame.size.width) < 0.05 && fabs(frame.size.height - state.nativeFrame.size.height) < 0.05) return;
                if (!HGIsApplying()) HGRestoreRightTransform(item);
                ((void (*)(id, SEL, CGRect))original)(item, frameSelector, frame);
                if (!HGIsApplying()) { HGRightStateFor(item).nativeFrame = item.frame; HGApplyRightItem(item); }
            };
        });
        SEL frameGetter = @selector(frame);
        HGInstall(NSClassFromString(name), frameGetter, ^id(IMP original) {
            return ^CGRect(UIView *item) {
                HGRightState *state = objc_getAssociatedObject(item, &HGRightStateKey);
                if (HGNativeRightLayoutDepth && state.scaled) return state.nativeFrame;
                return ((CGRect (*)(id, SEL))original)(item, frameGetter);
            };
        });
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
                if (nearest && distance <= MAX(22, nearest.bounds.size.height * HGNumber(@"right.scale") / 2)) {
                    // UIKit converts through the actual view transform, including scale and translation.
                    CGPoint local = [nearest convertPoint:point fromView:container];
                    return [nearest hitTest:local withEvent:event];
                }
            }
            return ((UIView *(*)(id, SEL, CGPoint, UIEvent *))original)(container, hitSelector, point, event);
        };
    });
    SEL fontSelector = @selector(setFont:);
    HGInstall(UILabel.class, fontSelector, ^id(IMP original) {
        return ^(UILabel *label, UIFont *font) {
            if (HGHandleTabFont(label, font, ^(UIFont *output) { ((void (*)(id, SEL, UIFont *))original)(label, fontSelector, output); })) return;
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












