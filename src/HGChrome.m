#import "HGCore.h"
#import "HGGeometry.h"

static char HGRightStateKey, HGFontStateKey;
static NSDictionary<NSString *, NSString *> *HGRightKeys(void) {
    return @{
        @"SSShortVideoRightInteractionAvatarView": @"right.avatar",
        @"SSShortVideoRightInteractionCollectView": @"right.collect",
        @"SSShortVideoRightInteractionCommentView": @"right.comment",
        @"SSShortVideoRightInteractionLikeView": @"right.like",
        @"SSShortVideoRightInteractionShareView": @"right.share"
    };
}
@interface HGRightState : NSObject
@property(nonatomic) BOOL hostHidden;
@property(nonatomic) BOOL hasHidden;
@property(nonatomic) CGAffineTransform hostTransform;
@property(nonatomic) CGAffineTransform appliedTransform;
@property(nonatomic) BOOL transformed;
@end
@implementation HGRightState
@end
@interface HGFontState : NSObject
@property(nonatomic, strong) UIFont *host;
@property(nonatomic, strong) UIFont *applied;
@end
@implementation HGFontState
@end

static HGRightState *HGRightStateFor(UIView *view) {
    HGRightState *state = objc_getAssociatedObject(view, &HGRightStateKey);
    if (!state) {
        state = [HGRightState new];
        state.hostHidden = view.hidden;
        state.hasHidden = YES;
        state.hostTransform = view.transform;
        objc_setAssociatedObject(view, &HGRightStateKey, state, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    return state;
}
static NSString *HGRightKey(UIView *view) {
    for (NSString *name in HGRightKeys()) if (HGIsClass(view, name)) return HGRightKeys()[name];
    return nil;
}
static NSArray<UIView *> *HGRightItems(UIView *container) {
    NSMutableArray *items = [NSMutableArray array];
    for (UIView *view in container.subviews) if (HGRightKey(view)) [items addObject:view];
    [items sortUsingComparator:^NSComparisonResult(UIView *a, UIView *b) {
        CGFloat ay = HGHostFrame(a).origin.y, by = HGHostFrame(b).origin.y;
        return ay < by ? NSOrderedAscending : ay > by ? NSOrderedDescending : NSOrderedSame;
    }];
    return items;
}
static void HGRestoreRightTransforms(UIView *container) {
    for (UIView *item in HGRightItems(container)) {
        HGRightState *state = HGRightStateFor(item);
        if (state.transformed) {
            if (!CGAffineTransformEqualToTransform(item.transform, state.appliedTransform)) {
                state.hostTransform = item.transform;
            }
            HGApply(^{ item.transform = state.hostTransform; });
            state.transformed = NO;
        }
        HGRestoreFrame(item);
    }
}
static void HGLayoutRight(UIView *container) {
    NSArray<UIView *> *items = HGRightItems(container);
    BOOL active = HGEnabled() && HGIsFeedView(container);
    NSMutableArray<UIView *> *shown = [NSMutableArray array];
    for (UIView *item in items) {
        HGRightState *state = HGRightStateFor(item);
        BOOL hidden = state.hostHidden || (active && !HGBool(HGRightKey(item)));
        HGApply(^{ item.hidden = hidden; });
        if (!hidden) [shown addObject:item];
    }
    if (!active) { HGRestoreFrame(container); return; }
    CGFloat scale = HGNumber(@"right.scale");
    CGFloat gap = 12.0 * scale, height = 0.0;
    for (UIView *item in shown) {
        height += HGInteractionPitch(HGHostFrame(item).size.height, scale);
    }
    height += gap * MAX(0, (NSInteger)shown.count - 1);
    CGRect host = HGHostFrame(container);
    CGFloat parentHeight = CGRectGetHeight(container.superview.bounds);
    CGFloat originalParentHeight = CGRectGetHeight(HGHostFrame(container.superview));
    CGFloat bottomGap = MAX(0.0, originalParentHeight - CGRectGetMaxY(host));
    CGRect target = host;
    target.size.height = MAX(1.0, height);
    target.origin.y = MAX(0.0, parentHeight - bottomGap - height);
    HGSetFrame(container, target);
    CGFloat y = 0;
    for (UIView *item in shown) {
        HGRightState *state = HGRightStateFor(item);
        CGRect source = HGHostFrame(item);
        if (CGRectIsEmpty(source)) continue;
        if (!state.transformed) state.hostTransform = item.transform;
        HGSetFrame(item, source); // Mark the unscaled frame for restoration before the next host layout.
        CGFloat pitch = HGInteractionPitch(source.size.height, scale);
        CGAffineTransform transform = CGAffineTransformConcat(state.hostTransform,
                                                              CGAffineTransformMakeScale(scale, scale));
        HGApply(^{
            item.transform = transform;
            item.center = CGPointMake(CGRectGetWidth(container.bounds) - MAX(44.0, source.size.width * scale) / 2.0,
                                      y + pitch / 2.0);
        });
        state.appliedTransform = transform;
        state.transformed = YES;
        y += pitch + gap;
    }
}
static BOOL HGInHeader(UIView *view) {
    for (UIView *parent = view; parent; parent = parent.superview) {
        if (HGIsClass(parent, @"SSVideoSeriesFeedHeaderView")) return YES;
    }
    return NO;
}
static void HGScaleHeaderFonts(UIView *root) {
    if ([root isKindOfClass:UILabel.class]) {
        UILabel *label = (UILabel *)root;
        HGFontState *state = objc_getAssociatedObject(label, &HGFontStateKey);
        BOOL active = HGEnabled() && HGBool(@"top.enabled") && HGIsFeedView(root) && HGInHeader(root);
        if (!state && active) {
            state = [HGFontState new];
            state.host = label.font;
            objc_setAssociatedObject(label, &HGFontStateKey, state, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        }
        if (state) {
            if (state.applied && ![label.font isEqual:state.applied]) state.host = label.font;
            if (!state.applied) state.host = label.font;
            UIFont *font = active ? [state.host fontWithSize:MAX(10.0, state.host.pointSize * HGNumber(@"top.scale"))]
                                  : state.host;
            if (![label.font isEqual:font]) HGApply(^{ label.font = font; });
            state.applied = active ? font : nil;
        }
    }
    for (UIView *child in root.subviews) HGScaleHeaderFonts(child);
}
void HGInstallChrome(void) {
    Class right = NSClassFromString(@"SSShortVideoRightInteractionView");
    SEL layout = @selector(layoutSubviews);
    HGInstall(right, layout, ^id(IMP original) {
        return ^(UIView *view) {
            if (!HGIsApplying()) HGRestoreRightTransforms(view);
            ((void (*)(id, SEL))original)(view, layout);
            if (!HGIsApplying()) HGLayoutRight(view);
        };
    });
    for (NSString *name in HGRightKeys()) {
        HGHookFrame(name, ^CGRect(UIView *view, CGRect frame) { return frame; });
        SEL hidden = @selector(setHidden:);
        HGInstall(NSClassFromString(name), hidden, ^id(IMP original) {
            return ^(UIView *view, BOOL value) {
                if (!HGIsApplying()) {
                    HGRightState *state = HGRightStateFor(view);
                    state.hostHidden = value;
                    value = value || (HGEnabled() && HGIsFeedView(view) && !HGBool(HGRightKey(view)));
                }
                ((void (*)(id, SEL, BOOL))original)(view, hidden, value);
            };
        });
        SEL inside = @selector(pointInside:withEvent:);
        HGInstall(NSClassFromString(name), inside, ^id(IMP original) {
            return ^BOOL(UIView *view, CGPoint point, UIEvent *event) {
                BOOL result = ((BOOL (*)(id, SEL, CGPoint, id))original)(view, inside, point, event);
                if (result || !HGEnabled() || !HGIsFeedView(view) || view.hidden) return result;
                CGFloat scale = HGNumber(@"right.scale");
                CGFloat dx = MAX(0.0, (44.0 / scale - CGRectGetWidth(view.bounds)) / 2.0);
                CGFloat dy = MAX(0.0, (44.0 / scale - CGRectGetHeight(view.bounds)) / 2.0);
                return CGRectContainsPoint(CGRectInset(view.bounds, -dx, -dy), point);
            };
        });
    }
    HGHookFrame(@"SSShortVideoRightInteractionView", ^CGRect(UIView *view, CGRect frame) { return frame; });
    HGHookLayout(@"SSVideoSeriesFeedHeaderView", ^(UIView *view) { HGScaleHeaderFonts(view); });
    HGHookLayout(@"FQRJXCategoryCollectionView", ^(UIView *view) {
        if (HGInHeader(view)) HGScaleHeaderFonts(view);
    });
}
