#import "HGCore.h"
#import "HGGeometry.h"

static char HGFeedStateKey, HGLayoutContextKey;
@interface HGLayoutContext : NSObject
@property(nonatomic) IMP item;
@property(nonatomic) IMP elements;
@property(nonatomic) IMP size;
@end
@implementation HGLayoutContext
@end
@interface HGFeedState : NSObject
@property(nonatomic, strong) HGLayoutContext *context;
@property(nonatomic, weak) UICollectionViewLayout *layout;
@property(nonatomic) BOOL allowed;
@property(nonatomic) BOOL active;
@property(nonatomic) BOOL updating;
@property(nonatomic) CGFloat sourceStride;
@property(nonatomic) CGFloat viewportHeight;
@end
@implementation HGFeedState
@end
static HGFeedState *HGFeedStateFor(UICollectionView *collection) {
    HGFeedState *state = objc_getAssociatedObject(collection, &HGFeedStateKey);
    if (!state) {
        state = [HGFeedState new];
        state.viewportHeight = CGRectGetHeight(HGHostFrame(collection));
        objc_setAssociatedObject(collection, &HGFeedStateKey, state, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    return state;
}
BOOL HGFeedExtensionOn(UIView *view) {
    UICollectionView *collection = nil;
    for (UIView *node = view; node; node = node.superview) if (HGIsClass(node, @"FQVCollectionView")) { collection = (id)node; break; }
    HGFeedState *state = objc_getAssociatedObject(collection, &HGFeedStateKey);
    return state.allowed && HGEnabled() && HGBool(@"video.extend") && HGIsFeedView(view);
}
static UICollectionViewLayoutAttributes *HGRawItem(UICollectionViewLayout *layout, HGLayoutContext *context, NSIndexPath *path) {
    if (!context.item) return nil;
    __block UICollectionViewLayoutAttributes *attributes;
    HGApply(^{ attributes = ((id (*)(id, SEL, id))context.item)(layout, @selector(layoutAttributesForItemAtIndexPath:), path); });
    return attributes;
}
static UICollectionViewLayoutAttributes *HGPageAttributes(UICollectionViewLayout *layout, HGLayoutContext *context, NSIndexPath *path) {
    UICollectionView *collection = layout.collectionView;
    if (path.section != 0 || path.item >= [collection numberOfItemsInSection:0]) return nil;
    UICollectionViewLayoutAttributes *attributes = [HGRawItem(layout, context, path) copy];
    if (!attributes) attributes = [UICollectionViewLayoutAttributes layoutAttributesForCellWithIndexPath:path];
    attributes.frame = CGRectMake(0, path.item * CGRectGetHeight(collection.bounds),
                                  CGRectGetWidth(collection.bounds), CGRectGetHeight(collection.bounds));
    return attributes;
}
static HGLayoutContext *HGInstallLayoutAdapter(UICollectionViewLayout *layout) {
    Class cls = object_getClass(layout);
    HGLayoutContext *context = objc_getAssociatedObject(cls, &HGLayoutContextKey);
    if (context) return context;
    context = [HGLayoutContext new];
    objc_setAssociatedObject(cls, &HGLayoutContextKey, context, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    SEL item = @selector(layoutAttributesForItemAtIndexPath:);
    HGInstall(cls, item, ^id(IMP original) {
        context.item = original;
        return ^id(UICollectionViewLayout *self, NSIndexPath *path) {
            if (!HGIsApplying() && HGFeedExtensionOn(self.collectionView)) return HGPageAttributes(self, context, path);
            return ((id (*)(id, SEL, id))original)(self, item, path);
        };
    });
    SEL elements = @selector(layoutAttributesForElementsInRect:);
    HGInstall(cls, elements, ^id(IMP original) {
        context.elements = original;
        return ^id(UICollectionViewLayout *self, CGRect rect) {
            UICollectionView *collection = self.collectionView;
            if (HGIsApplying() || !HGFeedExtensionOn(collection)) return ((id (*)(id, SEL, CGRect))original)(self, elements, rect);
            CGFloat height = CGRectGetHeight(collection.bounds);
            NSInteger count = [collection numberOfItemsInSection:0];
            if (height <= 0 || count <= 0 || CGRectIsEmpty(rect)) return @[];
            NSInteger first = MAX(0, (NSInteger)floor(CGRectGetMinY(rect) / height));
            NSInteger last = MIN(count - 1, (NSInteger)floor((CGRectGetMaxY(rect) - 0.01) / height));
            NSMutableArray *result = [NSMutableArray array];
            HGFeedState *state = HGFeedStateFor(collection);
            CGFloat ratio = state.sourceStride / height;
            CGRect sourceRect = CGRectMake(rect.origin.x, rect.origin.y * ratio, rect.size.width, rect.size.height * ratio);
            __block NSArray *originals;
            HGApply(^{ originals = ((id (*)(id, SEL, CGRect))original)(self, elements, sourceRect); });
            // Preserve host supplementary/decoration attributes. Cells use the expanded page stride.
            for (UICollectionViewLayoutAttributes *source in originals) {
                if (source.representedElementCategory == UICollectionElementCategoryCell) continue;
                UICollectionViewLayoutAttributes *copy = [source copy];
                CGRect frame = copy.frame; frame.origin.y /= ratio;
                copy.frame = frame; [result addObject:copy];
            }
            for (NSInteger page = first; page <= last; page++) {
                id attributes = HGPageAttributes(self, context, [NSIndexPath indexPathForItem:page inSection:0]);
                if (attributes) [result addObject:attributes];
            }
            return result;
        };
    });
    SEL size = @selector(collectionViewContentSize);
    HGInstall(cls, size, ^id(IMP original) {
        context.size = original;
        return ^CGSize(UICollectionViewLayout *self) {
            UICollectionView *collection = self.collectionView;
            if (!HGIsApplying() && HGFeedExtensionOn(collection)) {
                return CGSizeMake(CGRectGetWidth(collection.bounds),
                                  [collection numberOfItemsInSection:0] * CGRectGetHeight(collection.bounds));
            }
            return ((CGSize (*)(id, SEL))original)(self, size);
        };
    });
    SEL invalidate = @selector(shouldInvalidateLayoutForBoundsChange:);
    HGInstall(cls, invalidate, ^id(IMP original) {
        return ^BOOL(UICollectionViewLayout *self, CGRect bounds) {
            BOOL result = ((BOOL (*)(id, SEL, CGRect))original)(self, invalidate, bounds);
            if (!HGIsApplying() && HGFeedExtensionOn(self.collectionView) &&
                !CGSizeEqualToSize(bounds.size, self.collectionView.bounds.size)) return YES;
            return result;
        };
    });
    return context;
}
void HGUpdateFeedCollection(UICollectionView *collection) {
    if (!HGIsClass(collection, @"FQVCollectionView") || !collection.collectionViewLayout) return;
    HGFeedState *state = HGFeedStateFor(collection);
    if (state.updating) return;
    state.updating = YES;
    @try {
        UICollectionViewLayout *layout = collection.collectionViewLayout;
        if (layout != state.layout) {
            state.context = HGInstallLayoutAdapter(layout);
            state.layout = layout; state.allowed = NO;
        }
        if (!state.allowed && collection.numberOfSections == 1 && [collection numberOfItemsInSection:0] > 0 && HGIsFeedView(collection)) {
            UICollectionViewLayoutAttributes *first = HGRawItem(layout, state.context, [NSIndexPath indexPathForItem:0 inSection:0]);
            CGRect frame = first.frame;
            CGFloat width = CGRectGetWidth(collection.bounds);
            CGFloat hostHeight = CGRectGetHeight(HGHostFrame(collection));
            BOOL uniform = first && fabs(frame.origin.x) < 1 && fabs(frame.origin.y) < 1 &&
                           width > 0 && hostHeight > 100 && fabs(frame.size.width - width) < 1 && frame.size.height > 100 && frame.size.height >= hostHeight * 0.8;
            if (uniform && [collection numberOfItemsInSection:0] > 1) {
                CGRect second = HGRawItem(layout, state.context, [NSIndexPath indexPathForItem:1 inSection:0]).frame;
                uniform = fabs(second.origin.x) < 1 && fabs(second.origin.y - frame.size.height) < 1 &&
                          fabs(second.size.height - frame.size.height) < 1;
            }
            state.allowed = uniform;
            state.sourceStride = frame.size.height;
        }
        CGFloat oldHeight = state.viewportHeight, offset = collection.contentOffset.y;
        BOOL active = HGFeedExtensionOn(collection);
        if (active) {
            CGRect parent = collection.superview.bounds;
            HGSetFrame(collection, CGRectMake(0, 0, parent.size.width, parent.size.height));
        } else HGRestoreFrame(collection);
        CGFloat newHeight = CGRectGetHeight(collection.bounds);
        BOOL changed = state.active != active || fabs(oldHeight - newHeight) > 0.25;
        state.active = active;
        state.viewportHeight = newHeight;
        if (changed) {
            [layout invalidateLayout];
            if (!collection.tracking && !collection.dragging && !collection.decelerating &&
                collection.numberOfSections == 1) {
                CGPoint target = collection.contentOffset;
                target.y = HGPageOffset(offset, oldHeight, newHeight, [collection numberOfItemsInSection:0]);
                if (fabs(target.y - collection.contentOffset.y) > 0.25) [collection setContentOffset:target animated:NO];
            }
        }
    } @finally { state.updating = NO; }
}
