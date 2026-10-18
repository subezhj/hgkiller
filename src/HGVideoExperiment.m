#import "HGCore.h"
#import <math.h>
@interface HGClipSnapshot : NSObject
@property(nonatomic, weak) UIView *view;
@property(nonatomic) BOOL clips;
@end
@implementation HGClipSnapshot @end
@interface HGVideoExperiment : NSObject
@property(nonatomic, weak) UIView *picture;
@property(nonatomic, weak) UIView *cell;
@property(nonatomic, weak) UIView *bar;
@property(nonatomic, weak) UICollectionView *collection;
@property(nonatomic) CATransform3D source;
@property(nonatomic) CATransform3D applied;
@property(nonatomic, strong) CALayer *oldMask;
@property(nonatomic, strong) CAShapeLayer *mask;
@property(nonatomic, strong) NSArray<HGClipSnapshot *> *clips;
@property(nonatomic, strong) NSMapTable<UIView *, NSNumber *> *siblings;
@property(nonatomic) CGRect sourceBounds;
@property(nonatomic) CGRect target;
@property(nonatomic) CGPoint offset;
@end
@implementation HGVideoExperiment @end
static HGVideoExperiment *HGVideoState;
static __weak UIView *HGVideoRejectedPicture;
static NSString *HGVideoStatus;
static BOOL HGVideoUpdating;
static NSUInteger HGVideoScrollGeneration;
static UIView *HGAncestorNamed(UIView *view, NSString *name) {
    for (UIView *node = view.superview; node; node = node.superview) if (HGIsClass(node, name)) return node;
    return nil;
}
void HGRestoreVideoExperiment(void) {
    HGVideoRejectedPicture = nil;
    HGVideoExperiment *state = HGVideoState;
    if (!state) return;
    HGVideoState = nil;
    [CATransaction begin]; [CATransaction setDisableActions:YES];
    // Respect a host that has replaced its own transform/mask meanwhile.
    if (state.picture && CATransform3DEqualToTransform(state.picture.layer.sublayerTransform, state.applied)) state.picture.layer.sublayerTransform = state.source;
    if (state.cell.layer.mask == state.mask) state.cell.layer.mask = state.oldMask;
    for (HGClipSnapshot *clip in state.clips) if (clip.view.clipsToBounds != clip.clips) clip.view.clipsToBounds = clip.clips;
    for (UIView *sibling in state.siblings) {
        NSNumber *opacity = [state.siblings objectForKey:sibling];
        if (sibling.layer.opacity == 0) sibling.layer.opacity = opacity.floatValue;
    }
    [CATransaction commit];
    HGVideoStatus = @"视频扩展已恢复原生。";
    [state.bar setNeedsLayout];
}
void HGRestoreVideoExperimentForBar(UIView *bar) {
    if (HGVideoState.bar == bar) HGRestoreVideoExperiment();
}
NSString *HGVideoExperimentStatus(void) { return HGVideoStatus ?: @"视频扩展未启用。"; }
BOOL HGVideoCoversBar(UIView *bar) {
    CGRect barRect = [bar convertRect:bar.bounds toView:bar.window];
    if (HGVideoState && HGVideoState.bar == bar && HGPlaybackVisible(HGVideoState.picture) &&
        CGRectContainsRect(HGVideoState.target, barRect)) return YES;
    UIView *picture = HGCurrentPicture(bar.window);
    if (!picture) return NO;
    CGRect visible = [picture convertRect:picture.bounds toView:bar.window];
    for (UIView *node = picture; node; node = node.superview)
        if (node.clipsToBounds) visible = CGRectIntersection(visible, [node convertRect:node.bounds toView:bar.window]);
    return !CGRectIsNull(visible) && CGRectContainsRect(visible, barRect);
}
static BOOL HGVideoBlocked(UIView *root) {
    if (!HGPlaybackVisible(root)) return NO;
    for (NSString *name in @[@"SSBizVipVideoPayView", @"FQVPlayerErrorView"])
        if (HGIsClass(root, name)) return YES;
    for (UIView *child in root.subviews) if (HGVideoBlocked(child)) return YES;
    return NO;
}
void HGUpdateVideoExperiment(UIView *bar) {
    if (HGVideoUpdating) return;
    HGVideoUpdating = YES;
    @try {
        if (!HGEnabled() || !HGBool(@"tab.liquid.enabled") || !HGBool(@"tab.liquid.video") || !HGPlaybackVisible(bar)) {
            HGRestoreVideoExperiment(); HGVideoStatus = @"视频扩展未启用。"; return;
        }
        UIView *picture = HGCurrentPicture(bar.window);
        if (picture && picture == HGVideoRejectedPicture) return;
        UIViewController *owner = HGOwner(picture);
        UICollectionView *collection = (id)HGAncestorNamed(picture, @"FQVCollectionView");
        UIView *cell = HGAncestorNamed(picture, @"FQVShortVideoCell");
        if (!picture || !HGIsClass(owner, @"FQVShortVideoListViewController") || !collection || !cell || owner.presentedViewController || HGVideoBlocked(cell)) {
            HGRestoreVideoExperiment(); HGVideoStatus = @"黑底：当前页面无可扩展的播放单元。"; return;
        }
        CGRect page = [cell convertRect:cell.bounds toView:bar.window];
        CGRect display = [picture convertRect:picture.bounds toView:bar.window];
        CGRect target = CGRectMake(CGRectGetMinX(display), CGRectGetMinY(display), display.size.width, CGRectGetMaxY(bar.window.bounds) - CGRectGetMinY(display));
        CGFloat extra = target.size.height - display.size.height;
        if (collection.dragging || collection.decelerating || fabs(CGRectGetMinY(page)) > 1 ||
            picture.bounds.size.height / picture.bounds.size.width < 1.70 ||
            fabs(display.size.width - bar.window.bounds.size.width) > 1 || fabs(CGRectGetMinY(display)) > 1 ||
            extra <= 1 || extra > 120 || target.size.height / display.size.height > 1.20) {
            HGRestoreVideoExperiment(); HGVideoStatus = [NSString stringWithFormat:@"黑底：滚动或几何条件未匹配。\n当前页 y=%.1f，画面=%@\n容器高/宽=%.3f，待扩展=%.1f pt\n拖动=%@，减速=%@", CGRectGetMinY(page), NSStringFromCGRect(display), picture.bounds.size.height / picture.bounds.size.width, extra, collection.dragging ? @"是" : @"否", collection.decelerating ? @"是" : @"否"]; return;
        }
        UIView *metal = HGFindView(picture, @"TTMetalView");
        if (!metal || picture.subviews.count != 1 || metal.superview != picture || !HGPlaybackVisible(metal)) {
            HGRestoreVideoExperiment(); HGVideoStatus = @"黑底：未验证的实时渲染子层结构。"; return;
        }
        HGVideoExperiment *old = HGVideoState;
        if (old.picture == picture && CGRectEqualToRect(old.sourceBounds, picture.bounds) &&
            CGRectEqualToRect(old.target, target) && CGPointEqualToPoint(old.offset, collection.contentOffset)) {
            BOOL valid = cell.layer.mask == old.mask && CATransform3DEqualToTransform(picture.layer.sublayerTransform, old.applied);
            for (HGClipSnapshot *clip in old.clips) if (clip.view.clipsToBounds) valid = NO;
            if (valid) return;
            HGRestoreVideoExperiment(); HGVideoRejectedPicture = picture;
            HGVideoStatus = @"黑底：宿主重置了渲染或裁切状态，当前对象不再反复重写。"; return;
        }
        HGRestoreVideoExperiment();
        if (!CATransform3DIsIdentity(picture.layer.sublayerTransform)) {
            HGVideoStatus = @"黑底：宿主已使用渲染子层变换。"; return;
        }
        NSMutableArray *clips = [NSMutableArray array];
        for (UIView *node = picture; node && node != owner.view; node = node.superview) {
            if (node.layer.mask) { HGVideoStatus = @"黑底：裁切链存在宿主蒙版。"; return; }
            HGClipSnapshot *clip = [HGClipSnapshot new]; clip.view = node; clip.clips = node.clipsToBounds; [clips addObject:clip];
        }
        if (owner.view.bounds.size.height + 1 < target.size.height || owner.view.layer.mask) {
            HGVideoStatus = @"黑底：播放根视图未覆盖目标区域。"; return;
        }
        for (UIView *node = owner.view; node; node = node.superview) {
            CGRect rect = [node convertRect:node.bounds toView:bar.window];
            if (node.layer.mask || (node.clipsToBounds && !CGRectContainsRect(rect, target))) {
                HGVideoStatus = @"黑底：播放根视图上方仍存在裁切，不扩展该父级。"; return;
            }
        }
        for (UIViewController *node = owner; node; node = node.parentViewController)
            if (node.presentedViewController) { HGVideoStatus = @"黑底：播放页正在显示其他面板。"; return; }
        HGVideoExperiment *state = [HGVideoExperiment new];
        state.picture = picture; state.cell = cell; state.bar = bar; state.collection = collection;
        state.source = picture.layer.sublayerTransform; state.sourceBounds = picture.bounds; state.target = target;
        state.offset = collection.contentOffset; state.clips = clips; state.oldMask = cell.layer.mask;
        state.siblings = [NSMapTable weakToStrongObjectsMapTable];
        // Only the current cell may overflow. Restore before the next content-offset write.
        for (UIView *sibling in collection.subviews) if (HGIsClass(sibling, @"FQVShortVideoCell") && sibling != cell)
            [state.siblings setObject:@(sibling.layer.opacity) forKey:sibling];
        state.mask = [CAShapeLayer layer];
        CGRect local = [cell convertRect:bar.window.bounds fromView:bar.window];
        state.mask.frame = cell.bounds; state.mask.path = [UIBezierPath bezierPathWithRect:local].CGPath;
        CGFloat scale = target.size.height / display.size.height;
        CATransform3D transform = CATransform3DMakeScale(scale, scale, 1);
        transform.m42 = (target.size.height - display.size.height) / 2;
        state.applied = transform;
        HGVideoState = state;
        [CATransaction begin]; [CATransaction setDisableActions:YES];
        for (UIView *sibling in state.siblings) if (sibling.layer.opacity != 0) sibling.layer.opacity = 0;
        for (HGClipSnapshot *clip in clips) if (clip.view.clipsToBounds) clip.view.clipsToBounds = NO;
        cell.layer.mask = state.mask;
        picture.layer.sublayerTransform = transform;
        [CATransaction commit];
        HGVideoStatus = [NSString stringWithFormat:@"实验渲染扩展：%.3f 倍；容器比例 %.3f（非文件分辨率）。分页未修改。", scale, picture.bounds.size.height / picture.bounds.size.width];
    } @finally { HGVideoUpdating = NO; }
}
static void HGVideoAfterScroll(UICollectionView *view) {
    if (!HGEnabled() || !HGBool(@"tab.liquid.enabled") || !HGBool(@"tab.liquid.video")) return;
    NSUInteger generation = ++HGVideoScrollGeneration; __weak UICollectionView *weak = view;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.15 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        if (generation == HGVideoScrollGeneration && weak.window) {
            UIView *bar = HGFindView(weak.window, @"SSTabBar"); if (bar) [bar setNeedsLayout];
        }
    });
}
static void HGVideoBeforeScroll(UICollectionView *view) {
    if (HGVideoState.collection == view || HGAncestorNamed(HGVideoRejectedPicture, @"FQVCollectionView") == view) HGRestoreVideoExperiment();
}
void HGInstallVideoExperiment(void) {
    SEL offset = @selector(setContentOffset:);
    HGInstall(NSClassFromString(@"FQVCollectionView"), offset, ^id(IMP original) {
        return ^(UICollectionView *view, CGPoint value) {
            BOOL changed = !CGPointEqualToPoint(value, view.contentOffset);
            if (changed) HGVideoBeforeScroll(view);
            ((void (*)(id, SEL, CGPoint))original)(view, offset, value);
            if (changed) HGVideoAfterScroll(view);
        };
    });
    SEL bounds = @selector(setBounds:);
    HGInstall(NSClassFromString(@"FQVCollectionView"), bounds, ^id(IMP original) {
        return ^(UICollectionView *view, CGRect rect) {
            BOOL changed = !CGRectEqualToRect(view.bounds, rect);
            if (changed) HGVideoBeforeScroll(view);
            ((void (*)(id, SEL, CGRect))original)(view, bounds, rect);
            if (changed) HGVideoAfterScroll(view);
        };
    });
}
