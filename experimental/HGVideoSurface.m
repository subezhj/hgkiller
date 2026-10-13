#import "HGCore.h"
#import <limits.h>
#import <math.h>
static char HGSurfaceKey, HGSurfaceMetadataKey;
static NSHashTable<UIView *> *HGSurfaces;
@interface HGSurfaceState : NSObject
@property(nonatomic) CATransform3D host;
@property(nonatomic) BOOL clips;
@property(nonatomic) BOOL active;
@property(nonatomic, strong) CALayer *hostMask;
@property(nonatomic, strong) CAShapeLayer *mask;
@property(nonatomic, strong) NSHashTable<UIView *> *metadata;
@end
@implementation HGSurfaceState @end
@interface HGSurfaceMetadata : NSObject
@property(nonatomic) CATransform3D host;
@end
@implementation HGSurfaceMetadata @end
static BOOL HGVisible(UIView *view) {
    for (UIView *node = view; node; node = node.superview) if (node.hidden || node.alpha < 0.01) return NO;
    return view.window != nil;
}
static BOOL HGMetadataRoot(UIView *view) {
    for (NSString *name in @[@"FQVShortVideoVPlayerOutterMultiSeriesControlView", @"FQVShortVideoVPlayerSingleSeriesControlView", @"SSShortVideoAboveTopControllView", @"SSShortVideoOutterSeriesLeftContainerView", @"SSShortVideoSingleSeriesInfoLeftContainerView", @"SSShortVideoRightInteractionView", @"SSShortVideoBottomDistributionView", @"FQVShortVideoProgressView", @"FQVShortVideoProgressFloatView", @"FQVShortVideoProgressHighlightView", @"FQVShortVideoProgressHighlightTitleView"])
        if (HGIsClass(view, name)) return YES;
    return NO;
}
static void HGCollectMetadata(UIView *view, NSMutableArray *roots) {
    if (HGMetadataRoot(view)) { [roots addObject:view]; return; }
    for (UIView *child in view.subviews) HGCollectMetadata(child, roots);
}
static CGPoint HGSourceCenter(UIView *view, UIView *surface) {
    CGPoint p = CGPointMake(CGRectGetMidX(view.frame), CGRectGetMidY(view.frame));
    for (UIView *node = view.superview; node && node != surface; node = node.superview) {
        p.x += node.frame.origin.x - node.bounds.origin.x;
        p.y += node.frame.origin.y - node.bounds.origin.y;
    }
    p.x -= surface.bounds.origin.x; p.y -= surface.bounds.origin.y;
    return p;
}
static void HGRestoreMetadata(UIView *view) {
    HGSurfaceMetadata *state = objc_getAssociatedObject(view, &HGSurfaceMetadataKey);
    if (state && !CATransform3DEqualToTransform(view.layer.sublayerTransform, state.host)) view.layer.sublayerTransform = state.host;
}
static void HGProjectSurface(UIView *surface) {
    HGSurfaceState *state = objc_getAssociatedObject(surface, &HGSurfaceKey);
    UIView *bar = surface.window ? HGFindView(surface.window, @"SSTabBar") : nil;
    BOOL active = HGEnabled() && HGIsFeedView(surface) && HGVisible(surface) && bar && HGVisible(bar) && surface.window.bounds.size.height > surface.window.bounds.size.width;
    CGFloat scale = 1;
    if (active && surface.bounds.size.height > 0) {
        CGRect native = [surface convertRect:surface.bounds toView:surface.window];
        CGRect tab = [bar.superview convertRect:bar.frame toView:surface.window];
        CGFloat extra = CGRectGetMinY(tab) - CGRectGetMaxY(native);
        if (extra > 0.1 && extra <= 64) scale = 1 + extra / surface.bounds.size.height;
        else active = NO;
    } else active = NO;
    if (!state && !active) return;
    if (!state) {
        state = [HGSurfaceState new]; state.host = surface.layer.sublayerTransform;
        state.clips = surface.layer.masksToBounds; state.hostMask = surface.layer.mask;
        state.mask = [CAShapeLayer layer]; state.metadata = [NSHashTable weakObjectsHashTable];
        objc_setAssociatedObject(surface, &HGSurfaceKey, state, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    [CATransaction begin]; [CATransaction setDisableActions:YES];
    if (!active) {
        if (state.active) {
            surface.layer.sublayerTransform = state.host; surface.layer.masksToBounds = state.clips; surface.layer.mask = state.hostMask;
            for (UIView *view in state.metadata.allObjects) HGRestoreMetadata(view);
            [state.metadata removeAllObjects]; state.active = NO;
        }
        [CATransaction commit]; return;
    }
    CATransform3D transform = CATransform3DConcat(state.host, CATransform3DMakeScale(scale, scale, 1));
    transform.m42 += (scale - 1) * surface.bounds.size.height / 2;
    if (!CATransform3DEqualToTransform(surface.layer.sublayerTransform, transform)) surface.layer.sublayerTransform = transform;
    if (surface.layer.masksToBounds) surface.layer.masksToBounds = NO;
    CGRect maskRect = surface.bounds; maskRect.size.height *= scale;
    if (!CGRectEqualToRect(state.mask.frame, maskRect)) {
        state.mask.frame = maskRect;
        state.mask.path = [UIBezierPath bezierPathWithRect:CGRectMake(0, 0, maskRect.size.width, maskRect.size.height)].CGPath;
    }
    if (surface.layer.mask != state.mask) surface.layer.mask = state.mask;
    NSMutableArray<UIView *> *roots = [NSMutableArray array];
    for (UIView *child in surface.subviews) HGCollectMetadata(child, roots);
    for (UIView *old in state.metadata.allObjects) if (![roots containsObject:old]) HGRestoreMetadata(old);
    [state.metadata removeAllObjects];
    for (UIView *view in roots) {
        HGSurfaceMetadata *meta = objc_getAssociatedObject(view, &HGSurfaceMetadataKey);
        if (!meta) { meta = [HGSurfaceMetadata new]; meta.host = view.layer.sublayerTransform; objc_setAssociatedObject(view, &HGSurfaceMetadataKey, meta, OBJC_ASSOCIATION_RETAIN_NONATOMIC); }
        CGPoint p = HGSourceCenter(view, surface);
        CGSize shift = CGSizeMake((1 / scale - 1) * (p.x - surface.bounds.size.width / 2), (1 / scale - 1) * p.y);
        shift = CGSizeApplyAffineTransform(shift, CGAffineTransformInvert(view.transform));
        CATransform3D inverse = CATransform3DConcat(meta.host, CATransform3DMakeScale(1 / scale, 1 / scale, 1));
        inverse.m41 += shift.width; inverse.m42 += shift.height;
        if (!CATransform3DEqualToTransform(view.layer.sublayerTransform, inverse)) view.layer.sublayerTransform = inverse;
        [state.metadata addObject:view];
    }
    state.active = YES;
    [CATransaction commit];
}
static void HGTrackSurface(UIView *view) {
    if (!HGSurfaces) HGSurfaces = [NSHashTable weakObjectsHashTable];
    [HGSurfaces addObject:view]; HGApply(^{ HGProjectSurface(view); });
}
void HGInstallVideoSurface(void) {
    HGHookLayout(@"FQVCollectionView", ^(UIView *view) { HGTrackSurface(view); });
    SEL moved = @selector(didMoveToWindow);
    HGInstall(NSClassFromString(@"FQVCollectionView"), moved, ^id(IMP original) {
        return ^(UIView *view) { ((void (*)(id, SEL))original)(view, moved); HGTrackSurface(view); };
    });
    static dispatch_once_t once; dispatch_once(&once, ^{
        CFRunLoopObserverRef observer = CFRunLoopObserverCreateWithHandler(kCFAllocatorDefault, kCFRunLoopBeforeWaiting, true, LONG_MAX, ^(CFRunLoopObserverRef observer, CFRunLoopActivity activity) {
            for (UIView *view in HGSurfaces.allObjects) if (view.window) HGApply(^{ HGProjectSurface(view); });
        });
        CFRunLoopAddObserver(CFRunLoopGetMain(), observer, kCFRunLoopCommonModes); CFRelease(observer);
    });
}
