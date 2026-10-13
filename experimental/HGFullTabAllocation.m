#import "HGCore.h"
#import <math.h>

// Real viewport geometry. Never stretch the collection's rendered layer tree.
static char HGAllocationKey;
static NSUInteger HGSourceLayoutDepth;
static BOOL HGAllocationUpdating;
@interface HGAllocation : NSObject
@property(nonatomic) CGRect source;
@property(nonatomic) CGRect applied;
@property(nonatomic) BOOL active;
@end
@implementation HGAllocation @end

static HGAllocation *HGAllocationState(UIView *view) {
    HGAllocation *state = objc_getAssociatedObject(view, &HGAllocationKey);
    if (!state) {
        state = [HGAllocation new]; state.source = view.frame; state.applied = view.frame;
        objc_setAssociatedObject(view, &HGAllocationKey, state, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    return state;
}
static BOOL HGAllocationVisible(UIView *view) {
    if (!view.window || view.window.windowLevel != UIWindowLevelNormal) return NO;
    for (UIView *node = view; node; node = node.superview) if (node.hidden || node.alpha < 0.01) return NO;
    return YES;
}
static BOOL HGAllocationEnabled(UIView *bar) {
    return HGEnabled() && HGBool(@"tab.layout.enabled") && HGAllocationVisible(bar) &&
        bar.window.bounds.size.height > bar.window.bounds.size.width;
}
static CGRect HGAllocationTarget(UIView *view, CGRect source) {
    if (HGIsClass(view, @"SSTabBar")) {
        if (!HGAllocationEnabled(view)) return source;
        CGFloat safe = view.window.safeAreaInsets.bottom;
        CGFloat height = MIN(source.size.height, MAX(safe + 28, HGNumber(@"tab.appearance.height")));
        CGRect target = source; target.origin.y = CGRectGetMaxY(source) - height; target.size.height = height;
        return target;
    }
    if (!HGIsFeedView(view) || !HGAllocationVisible(view)) return source;
    UIView *bar = HGFindView(view.window, @"SSTabBar");
    if (!HGAllocationEnabled(bar)) return source;
    HGAllocation *tab = HGAllocationState(bar);
    CGRect oldTab = [bar.superview convertRect:tab.source toView:view.window];
    CGRect newTab = [bar.superview convertRect:HGAllocationTarget(bar, tab.source) toView:view.window];
    CGRect viewport = [view.superview convertRect:source toView:view.window];
    CGFloat gap = CGRectGetMinY(oldTab) - CGRectGetMaxY(viewport);
    // Captured home viewport ends 6 pt before the tab. Exclude full-height detail playback.
    if (gap < -0.5 || gap > 16 || source.size.height < 100) return source;
    CGFloat extra = CGRectGetMinY(newTab) - CGRectGetMaxY(viewport);
    if (extra < 0 || extra > 64) return source;
    CGRect target = source; target.size.height += extra; return target;
}
static void HGAllocationLayoutHooks(UICollectionViewLayout *layout);
static void HGAllocationContent(UIView *root, CGFloat nativeHeight, CGFloat targetHeight, BOOL active) {
    for (UIView *view in root.subviews.copy) {
        // These retain their host layout and existing font/interaction hooks.
        if (HGIsClass(view, @"SSShortVideoRightInteractionView") || HGIsClass(view, @"SSShortVideoOutterSeriesLeftContainerView") ||
            HGIsClass(view, @"SSShortVideoSingleSeriesInfoLeftContainerView")) continue;
        HGAllocation *state = objc_getAssociatedObject(view, &HGAllocationKey);
        CGRect source = view.frame;
        if (state && state.active && CGRectEqualToRect(source, state.applied)) source = state.source;
        CGRect target = source;
        BOOL full = fabs(source.origin.y) < 0.5 && fabs(source.size.height - nativeHeight) < 0.5;
        BOOL bottom = (HGIsClass(view, @"FQVShortVideoBaseInsertView") && source.size.height < 100 && fabs(CGRectGetMaxY(source) - nativeHeight) < 0.5) ||
            (HGIsClass(view, @"FQVShortVideoProgressView") && source.size.height < 100 && fabs(CGRectGetMaxY(source) - nativeHeight) <= 8);
        if (active && full) {
            target.size.height = targetHeight;
            if (HGIsClass(root, @"TTMetalView") && HGIsClass(view, @"MTKView")) target.size.width = root.bounds.size.width;
            if (HGIsClass(view, @"TTMetalView")) {
                CGFloat center = CGRectGetMidX(source); target.size.width *= targetHeight / nativeHeight; target.origin.x = center - target.size.width / 2;
            }
        } else if (active && bottom) target.origin.y += targetHeight - nativeHeight;
        if (full || bottom || state) {
            if (!state) state = HGAllocationState(view);
            state.source = source; state.applied = target; state.active = !CGRectEqualToRect(source, target);
            if (!CGRectEqualToRect(view.frame, target)) HGApply(^{ view.frame = target; });
        }
        BOOL hostSized = active && fabs(source.origin.y) < 0.5 && fabs(source.size.height - targetHeight) < 0.5;
        if (full || hostSized || (state && fabs(source.size.height - nativeHeight) < 0.5)) HGAllocationContent(view, nativeHeight, targetHeight, active);
    }
}
static void HGAllocationCell(UIView *cell) {
    UIView *node = cell.superview;
    while (node && !HGIsClass(node, @"FQVCollectionView")) node = node.superview;
    HGAllocation *state = node ? objc_getAssociatedObject(node, &HGAllocationKey) : nil;
    if (state) HGAllocationContent(cell, state.source.size.height, state.applied.size.height, state.active);
}
static void HGAllocationApply(UIView *view) {
    HGAllocation *state = HGAllocationState(view);
    if (!state.active || !CGRectEqualToRect(view.frame, state.applied)) state.source = view.frame;
    CGRect target = HGAllocationTarget(view, state.source);
    BOOL changed = !CGRectEqualToRect(view.frame, target);
    CGFloat oldPage = view.bounds.size.height;
    CGPoint offset = CGPointZero;
    UICollectionView *collection = HGIsClass(view, @"FQVCollectionView") ? (id)view : nil;
    if (collection) { offset = collection.contentOffset; HGAllocationLayoutHooks(collection.collectionViewLayout); }
    state.applied = target; state.active = !CGRectEqualToRect(target, state.source);
    if (changed) HGApply(^{ view.frame = target; });
    if (changed && collection) {
        [collection.collectionViewLayout invalidateLayout];
        // Preserve the exact page/fraction through a settings or cold-start resize.
        if (oldPage > 0 && !collection.dragging && !collection.decelerating) {
            CGPoint next = CGPointMake(offset.x, offset.y / oldPage * target.size.height);
            if (!CGPointEqualToPoint(collection.contentOffset, next)) [collection setContentOffset:next animated:NO];
        }
    }
}
void HGReflowTabAllocation(UIView *bar) {
    if (!bar.window || HGIsApplying() || HGAllocationUpdating) return;
    HGAllocationUpdating = YES;
    @try {
        HGAllocationApply(bar);
        NSMutableArray<UIView *> *queue = [NSMutableArray arrayWithObject:bar.window];
        while (queue.count) {
            UIView *view = queue.lastObject; [queue removeLastObject];
            if (HGIsClass(view, @"FQVCollectionView")) HGAllocationApply(view);
            else [queue addObjectsFromArray:view.subviews];
        }
    } @finally { HGAllocationUpdating = NO; }
}
static HGAllocation *HGLayoutState(UICollectionViewLayout *layout) {
    if (!HGIsClass(layout.collectionView, @"FQVCollectionView")) return nil;
    HGAllocation *state = objc_getAssociatedObject(layout.collectionView, &HGAllocationKey);
    return state.active && state.source.size.height > 0 ? state : nil;
}
static UICollectionViewLayoutAttributes *HGAllocationAttributes(UICollectionViewLayoutAttributes *attributes, HGAllocation *state) {
    if (!attributes || !state) return attributes;
    UICollectionViewLayoutAttributes *copy = [attributes copy];
    CGRect frame = copy.frame;
    CGFloat scale = state.applied.size.height / state.source.size.height;
    frame.origin.y *= scale; frame.size.height *= scale; copy.frame = frame;
    return copy;
}
static void HGAllocationLayoutHooks(UICollectionViewLayout *layout) {
    Class cls = layout.class;
    if (!cls || cls == UICollectionViewLayout.class) return;
    SEL prepare = @selector(prepareLayout);
    HGInstall(cls, prepare, ^id(IMP original) {
        return ^(UICollectionViewLayout *object) {
            HGAllocation *state = HGLayoutState(object);
            if (state) HGSourceLayoutDepth++;
            @try { ((void (*)(id, SEL))original)(object, prepare); }
            @finally { if (state) HGSourceLayoutDepth--; }
        };
    });
    SEL size = @selector(collectionViewContentSize);
    HGInstall(cls, size, ^id(IMP original) {
        return ^CGSize(UICollectionViewLayout *object) {
            HGAllocation *state = HGLayoutState(object); BOOL nested = HGSourceLayoutDepth > 0;
            CGSize value;
            if (state) HGSourceLayoutDepth++;
            @try { value = ((CGSize (*)(id, SEL))original)(object, size); }
            @finally { if (state) HGSourceLayoutDepth--; }
            if (state && !nested) value.height *= state.applied.size.height / state.source.size.height;
            return value;
        };
    });
    SEL item = @selector(layoutAttributesForItemAtIndexPath:);
    HGInstall(cls, item, ^id(IMP original) {
        return ^UICollectionViewLayoutAttributes *(UICollectionViewLayout *object, NSIndexPath *path) {
            HGAllocation *state = HGLayoutState(object); BOOL nested = HGSourceLayoutDepth > 0;
            UICollectionViewLayoutAttributes *value;
            if (state) HGSourceLayoutDepth++;
            @try { value = ((id (*)(id, SEL, id))original)(object, item, path); }
            @finally { if (state) HGSourceLayoutDepth--; }
            return !nested ? HGAllocationAttributes(value, state) : value;
        };
    });
    SEL elements = @selector(layoutAttributesForElementsInRect:);
    HGInstall(cls, elements, ^id(IMP original) {
        return ^NSArray *(UICollectionViewLayout *object, CGRect rect) {
            HGAllocation *state = HGLayoutState(object); BOOL nested = HGSourceLayoutDepth > 0;
            if (state && !nested) { CGFloat ratio = state.source.size.height / state.applied.size.height; rect.origin.y *= ratio; rect.size.height *= ratio; }
            NSArray *values;
            if (state) HGSourceLayoutDepth++;
            @try { values = ((id (*)(id, SEL, CGRect))original)(object, elements, rect); }
            @finally { if (state) HGSourceLayoutDepth--; }
            if (!state || nested) return values;
            NSMutableArray *result = [NSMutableArray arrayWithCapacity:values.count];
            for (UICollectionViewLayoutAttributes *value in values) [result addObject:HGAllocationAttributes(value, state)];
            return result;
        };
    });
    SEL snap = @selector(targetContentOffsetForProposedContentOffset:withScrollingVelocity:);
    HGInstall(cls, snap, ^id(IMP original) {
        return ^CGPoint(UICollectionViewLayout *object, CGPoint point, CGPoint velocity) {
            HGAllocation *state = HGLayoutState(object); BOOL nested = HGSourceLayoutDepth > 0;
            CGFloat scale = state && !nested ? state.applied.size.height / state.source.size.height : 1;
            point.y /= scale; velocity.y /= scale;
            CGPoint value;
            if (state) HGSourceLayoutDepth++;
            @try { value = ((CGPoint (*)(id, SEL, CGPoint, CGPoint))original)(object, snap, point, velocity); }
            @finally { if (state) HGSourceLayoutDepth--; }
            value.y *= scale; return value;
        };
    });
    SEL resting = @selector(targetContentOffsetForProposedContentOffset:);
    HGInstall(cls, resting, ^id(IMP original) {
        return ^CGPoint(UICollectionViewLayout *object, CGPoint point) {
            HGAllocation *state = HGLayoutState(object); BOOL nested = HGSourceLayoutDepth > 0;
            CGFloat scale = state && !nested ? state.applied.size.height / state.source.size.height : 1;
            point.y /= scale; CGPoint value;
            if (state) HGSourceLayoutDepth++;
            @try { value = ((CGPoint (*)(id, SEL, CGPoint))original)(object, resting, point); }
            @finally { if (state) HGSourceLayoutDepth--; }
            value.y *= scale; return value;
        };
    });
}
void HGInstallTabAllocation(void) {
    for (NSString *name in @[@"SSTabBar", @"FQVCollectionView"]) {
        SEL setter = @selector(setFrame:);
        HGInstall(NSClassFromString(name), setter, ^id(IMP original) {
            return ^(UIView *view, CGRect frame) {
                HGAllocation *state = HGAllocationState(view);
                if (HGIsApplying()) { ((void (*)(id, SEL, CGRect))original)(view, setter, frame); return; }
                if (state.active && CGRectEqualToRect(frame, state.applied)) return;
                state.source = frame;
                CGRect target = HGAllocationTarget(view, frame);
                state.applied = target; state.active = !CGRectEqualToRect(target, frame);
                if (state.active && CGRectEqualToRect(view.frame, target)) return;
                UICollectionView *collection = HGIsClass(view, @"FQVCollectionView") ? (id)view : nil;
                CGFloat oldPage = view.bounds.size.height; CGPoint offset = collection.contentOffset;
                if (collection) HGAllocationLayoutHooks(collection.collectionViewLayout);
                ((void (*)(id, SEL, CGRect))original)(view, setter, target);
                if (collection && fabs(oldPage - target.size.height) > 0.1) {
                    [collection.collectionViewLayout invalidateLayout];
                    if (oldPage > 0 && !collection.dragging && !collection.decelerating)
                        [collection setContentOffset:CGPointMake(offset.x, offset.y / oldPage * target.size.height) animated:NO];
                }
            };
        });
    }
    SEL bounds = @selector(bounds);
    HGInstall(NSClassFromString(@"FQVCollectionView"), bounds, ^id(IMP original) {
        return ^CGRect(UIView *view) {
            CGRect rect = ((CGRect (*)(id, SEL))original)(view, bounds);
            HGAllocation *state = objc_getAssociatedObject(view, &HGAllocationKey);
            if (HGSourceLayoutDepth && state.active) { rect.size.height = state.source.size.height; rect.origin.y *= state.source.size.height / state.applied.size.height; }
            return rect;
        };
    });
    SEL frameGetter = @selector(frame);
    HGInstall(NSClassFromString(@"FQVCollectionView"), frameGetter, ^id(IMP original) {
        return ^CGRect(UIView *view) {
            HGAllocation *state = objc_getAssociatedObject(view, &HGAllocationKey);
            if (HGSourceLayoutDepth && state.active) return state.source;
            return ((CGRect (*)(id, SEL))original)(view, frameGetter);
        };
    });
    HGHookLayout(@"FQVShortVideoCell", ^(UIView *cell) { HGAllocationCell(cell); });
    HGHookLayout(@"FQVCollectionView", ^(UIView *view) {
        for (UICollectionViewCell *cell in ((UICollectionView *)view).visibleCells) HGAllocationCell(cell);
    });
}
