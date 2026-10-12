#import "HGCore.h"
#import "HGGeometry.h"

void HGInstallChrome(void);
static char HGFlowKey, HGVideoSizeKey, HGInsertRoleKey, HGTabStateKey, HGDecorationKey, HGPlayerClipKey;

@interface HGFlowState : NSObject
@property(nonatomic) CGSize itemSize;
@property(nonatomic) CGSize estimated;
@property(nonatomic) UIEdgeInsets sectionInset;
@property(nonatomic) CGFloat lineSpacing;
@property(nonatomic) CGFloat interitemSpacing;
@property(nonatomic) UIEdgeInsets contentInset;
@property(nonatomic) UIScrollViewContentInsetAdjustmentBehavior adjustment;
@property(nonatomic) BOOL paging;
@property(nonatomic) BOOL active;
@property(nonatomic) CGFloat viewportHeight;
@end
@implementation HGFlowState
@end
@interface HGTabState : NSObject
@property(nonatomic, strong) UIVisualEffectView *glass;
@property(nonatomic) CGFloat cornerRadius;
@property(nonatomic) BOOL clips;
@property(nonatomic) BOOL active;
@end
@implementation HGTabState
@end

static CGRect HGCGRect(HGRect r) { return CGRectMake(r.x, r.y, r.width, r.height); }
static UICollectionView *HGFeedCollection(UIView *view) {
    for (UIView *node = view; node; node = node.superview) {
        if (HGIsClass(node, @"FQVCollectionView")) return (UICollectionView *)node;
    }
    return nil;
}
static BOOL HGCanExtend(UIView *view) {
    UICollectionView *collection = HGFeedCollection(view);
    return HGEnabled() && HGBool(@"video.extend") && HGIsFeedView(view) &&
           [collection.collectionViewLayout isKindOfClass:UICollectionViewFlowLayout.class] &&
           ((UICollectionViewFlowLayout *)collection.collectionViewLayout).scrollDirection == UICollectionViewScrollDirectionVertical;
}
static CGRect HGFillParent(UIView *view, CGRect frame) {
    if (!HGCanExtend(view) || !view.superview || CGRectIsEmpty(view.superview.bounds)) return frame;
    return CGRectMake(0, 0, CGRectGetWidth(view.superview.bounds), CGRectGetHeight(view.superview.bounds));
}
static void HGLayoutFill(UIView *view) {
    if (HGCanExtend(view)) HGSetFrame(view, HGFillParent(view, HGHostFrame(view)));
    else HGRestoreFrame(view);
}
static void HGConfigureFlow(UICollectionView *collection) {
    UICollectionViewFlowLayout *flow = (id)collection.collectionViewLayout;
    if (![flow isKindOfClass:UICollectionViewFlowLayout.class]) return;
    HGFlowState *state = objc_getAssociatedObject(flow, &HGFlowKey);
    BOOL active = HGCanExtend(collection);
    if (!state && !active) return;
    if (!state) {
        state = [HGFlowState new];
        objc_setAssociatedObject(flow, &HGFlowKey, state, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    if (active && !state.active) {
        state.itemSize = flow.itemSize;
        state.estimated = flow.estimatedItemSize;
        state.sectionInset = flow.sectionInset;
        state.lineSpacing = flow.minimumLineSpacing;
        state.interitemSpacing = flow.minimumInteritemSpacing;
        state.contentInset = collection.contentInset;
        state.adjustment = collection.contentInsetAdjustmentBehavior;
        state.paging = collection.pagingEnabled;
        state.viewportHeight = CGRectGetHeight(collection.bounds);
    }
    if (active) {
        CGSize size = collection.bounds.size;
        if (size.width <= 0 || size.height <= 0) return;
        if (!CGSizeEqualToSize(flow.itemSize, size)) flow.itemSize = size;
        if (!CGSizeEqualToSize(flow.estimatedItemSize, CGSizeZero)) flow.estimatedItemSize = CGSizeZero;
        if (!UIEdgeInsetsEqualToEdgeInsets(flow.sectionInset, UIEdgeInsetsZero)) flow.sectionInset = UIEdgeInsetsZero;
        if (flow.minimumLineSpacing != 0) flow.minimumLineSpacing = 0;
        if (flow.minimumInteritemSpacing != 0) flow.minimumInteritemSpacing = 0;
        if (!UIEdgeInsetsEqualToEdgeInsets(collection.contentInset, UIEdgeInsetsZero)) collection.contentInset = UIEdgeInsetsZero;
        collection.contentInsetAdjustmentBehavior = UIScrollViewContentInsetAdjustmentNever;
        collection.pagingEnabled = YES;
    } else if (state.active) {
        flow.itemSize = state.itemSize;
        flow.estimatedItemSize = state.estimated;
        flow.sectionInset = state.sectionInset;
        flow.minimumLineSpacing = state.lineSpacing;
        flow.minimumInteritemSpacing = state.interitemSpacing;
        collection.contentInset = state.contentInset;
        collection.contentInsetAdjustmentBehavior = state.adjustment;
        collection.pagingEnabled = state.paging;
    }
    state.active = active;
}
static void HGInstallCollectionSizing(UICollectionView *collection) {
    UICollectionViewFlowLayout *flow = (id)collection.collectionViewLayout;
    if (![flow isKindOfClass:UICollectionViewFlowLayout.class]) return;
    SEL prepare = @selector(prepareLayout);
    HGInstall(object_getClass(flow), prepare, ^id(IMP original) {
        return ^(UICollectionViewFlowLayout *layout) {
            if (HGIsClass(layout.collectionView, @"FQVCollectionView")) HGConfigureFlow(layout.collectionView);
            ((void (*)(id, SEL))original)(layout, prepare);
        };
    });
    SEL size = @selector(collectionView:layout:sizeForItemAtIndexPath:);
    HGInstall(object_getClass(collection.delegate), size, ^id(IMP original) {
        return ^CGSize(id delegate, UICollectionView *view, UICollectionViewLayout *layout, NSIndexPath *path) {
            if (HGIsClass(view, @"FQVCollectionView") && HGCanExtend(view)) return view.bounds.size;
            return ((CGSize (*)(id, SEL, id, id, id))original)(delegate, size, view, layout, path);
        };
    });
    SEL insets = @selector(collectionView:layout:insetForSectionAtIndex:);
    HGInstall(object_getClass(collection.delegate), insets, ^id(IMP original) {
        return ^UIEdgeInsets(id delegate, UICollectionView *view, UICollectionViewLayout *layout, NSInteger section) {
            if (HGIsClass(view, @"FQVCollectionView") && HGCanExtend(view)) return UIEdgeInsetsZero;
            return ((UIEdgeInsets (*)(id, SEL, id, id, NSInteger))original)(delegate, insets, view, layout, section);
        };
    });
    for (NSString *name in @[@"collectionView:layout:minimumLineSpacingForSectionAtIndex:",
                             @"collectionView:layout:minimumInteritemSpacingForSectionAtIndex:"]) {
        SEL spacing = NSSelectorFromString(name);
        HGInstall(object_getClass(collection.delegate), spacing, ^id(IMP original) {
            return ^CGFloat(id delegate, UICollectionView *view, UICollectionViewLayout *layout, NSInteger section) {
                if (HGIsClass(view, @"FQVCollectionView") && HGCanExtend(view)) return 0;
                return ((CGFloat (*)(id, SEL, id, id, NSInteger))original)(delegate, spacing, view, layout, section);
            };
        });
    }
}
static void HGLayoutCollection(UICollectionView *collection) {
    HGInstallCollectionSizing(collection);
    HGFlowState *state = objc_getAssociatedObject(collection.collectionViewLayout, &HGFlowKey);
    CGFloat oldHeight = state.viewportHeight ?: CGRectGetHeight(HGHostFrame(collection));
    CGFloat offset = collection.contentOffset.y;
    if (HGCanExtend(collection)) HGSetFrame(collection, HGFillParent(collection, HGHostFrame(collection)));
    else HGRestoreFrame(collection);
    HGConfigureFlow(collection);
    CGFloat newHeight = CGRectGetHeight(collection.bounds);
    state = objc_getAssociatedObject(collection.collectionViewLayout, &HGFlowKey);
    if (fabs(oldHeight - newHeight) > 0.5 && oldHeight > 0 && newHeight > 0) {
        [collection.collectionViewLayout invalidateLayout];
        if (!collection.tracking && !collection.dragging && !collection.decelerating) {
            NSUInteger count = 0;
            for (NSInteger section = 0; section < collection.numberOfSections; section++) {
                count += [collection numberOfItemsInSection:section];
            }
            CGPoint target = collection.contentOffset;
            target.y = HGPageOffset(offset, oldHeight, newHeight, count);
            [collection setContentOffset:target animated:NO];
        }
    }
    state.viewportHeight = newHeight;
}
static CGRect HGVideoFrame(UIView *view, CGRect frame) {
    if (!HGCanExtend(view) || !HGIsClass(view.superview, @"FQVPlayer")) return frame;
    NSValue *size = objc_getAssociatedObject(view, &HGVideoSizeKey);
    CGSize source = size ? size.CGSizeValue : frame.size;
    return HGCGRect(HGVideoRect(CGRectGetWidth(view.superview.bounds),
                               CGRectGetHeight(view.superview.bounds),
                               source.width, source.height, HGBool(@"video.fillPortrait")));
}
static CGFloat HGControlBottom(UIView *view) {
    UIWindow *window = view.window;
    if (!window) return CGRectGetHeight(view.bounds);
    CGFloat screenBottom = CGRectGetHeight(window.bounds) - window.safeAreaInsets.bottom - 8.0;
    if (HGBool(@"tab.glass")) {
        screenBottom = HGGlassRect(CGRectGetWidth(window.bounds), CGRectGetHeight(window.bounds),
                                  window.safeAreaInsets.bottom).y - 12.0;
    }
    CGPoint point = [view convertPoint:CGPointMake(0, screenBottom) fromView:window];
    return MAX(0.0, MIN(CGRectGetHeight(view.bounds), point.y));
}
static CGRect HGInsertFrame(UIView *view, CGRect frame) {
    if (!HGCanExtend(view)) return frame;
    NSNumber *role = objc_getAssociatedObject(view, &HGInsertRoleKey);
    if (!role && frame.size.height > 0) {
        // The captured feed has a large information layer and a 44pt bottom distribution layer.
        if (frame.origin.y < 1.0 && frame.size.height > 100.0) role = @0;
        else if (frame.origin.y > 100.0 && frame.size.height <= 60.0) role = @1;
        if (role) objc_setAssociatedObject(view, &HGInsertRoleKey, role, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    if (!role) return frame;
    CGFloat bottom = HGControlBottom(view.superview);
    if (role.integerValue == 0) frame.size.height = MAX(1.0, bottom - 44.0);
    else frame.origin.y = MAX(0.0, bottom - frame.size.height);
    return frame;
}
static CGRect HGAnchorBottom(UIView *view, CGRect frame) {
    if (!HGCanExtend(view)) return frame;
    CGRect parentHost = HGHostFrame(view.superview);
    CGFloat gap = MAX(0.0, parentHost.size.height - CGRectGetMaxY(frame));
    frame.origin.y = MAX(0.0, CGRectGetHeight(view.superview.bounds) - gap - frame.size.height);
    return frame;
}
static BOOL HGTabEligible(UIView *view) {
    for (UIView *node = view; node; node = node.superview) {
        if (HGIsClass(node.nextResponder, @"SSTabBarController")) return YES;
    }
    return NO;
}
static CGRect HGTabFrame(UIView *view, CGRect frame) {
    if (!HGEnabled() || !HGBool(@"tab.glass") || !HGTabEligible(view) || !view.superview || !view.window) return frame;
    CGRect windowRect = HGCGRect(HGGlassRect(CGRectGetWidth(view.window.bounds), CGRectGetHeight(view.window.bounds),
                                            view.window.safeAreaInsets.bottom));
    return [view.superview convertRect:windowRect fromView:view.window];
}
static void HGVisitTabDecoration(UIView *view, BOOL active) {
    // Clear only background decorations, never replace the native tab actions or labels.
    NSMutableDictionary *state = objc_getAssociatedObject(view, &HGDecorationKey);
    if (active) {
        if (!state) {
            state = [NSMutableDictionary dictionary];
            state[@"color"] = view.backgroundColor ?: NSNull.null;
            state[@"hidden"] = @(view.hidden);
            objc_setAssociatedObject(view, &HGDecorationKey, state, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        }
        HGApply(^{
            view.backgroundColor = UIColor.clearColor;
            if ([NSStringFromClass(view.class) hasPrefix:@"_UIBarBackground"]) view.hidden = YES;
        });
    } else if (state) {
        HGApply(^{
            view.backgroundColor = state[@"color"] == NSNull.null ? nil : state[@"color"];
            view.hidden = [state[@"hidden"] boolValue];
        });
        objc_setAssociatedObject(view, &HGDecorationKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
}
// Runtime declarations of Apple's public UIGlassEffect API permit builds with older SDKs.
@protocol HGGlassEffectAPI <NSObject>
- (instancetype)initWithStyle:(NSInteger)style;
- (void)setInteractive:(BOOL)interactive;
@end
static UIVisualEffect *HGMakeGlassEffect(void) {
    Class cls = NSClassFromString(@"UIGlassEffect");
    if (cls && [cls instancesRespondToSelector:@selector(initWithStyle:)]) {
        id effect = [(id<HGGlassEffectAPI>)[cls alloc] initWithStyle:0];
        if ([effect isKindOfClass:UIVisualEffect.class]) {
            if ([effect respondsToSelector:@selector(setInteractive:)]) [(id<HGGlassEffectAPI>)effect setInteractive:YES];
            return effect;
        }
    }
    return [UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemUltraThinMaterial];
}
static void HGLayoutTab(UIView *view) {
    BOOL active = HGEnabled() && HGBool(@"tab.glass") && HGTabEligible(view);
    HGTabState *state = objc_getAssociatedObject(view, &HGTabStateKey);
    if (!active && !state) return;
    if (!state) {
        state = [HGTabState new];
        state.cornerRadius = view.layer.cornerRadius;
        state.clips = view.clipsToBounds;
        objc_setAssociatedObject(view, &HGTabStateKey, state, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    if (active) HGSetFrame(view, HGTabFrame(view, HGHostFrame(view)));
    else HGRestoreFrame(view);
    HGVisitTabDecoration(view, active);
    for (UIView *child in view.subviews) {
        if (child == state.glass || [child isKindOfClass:UIControl.class]) continue;
        if ([child isKindOfClass:UIVisualEffectView.class] ||
            [NSStringFromClass(child.class) hasPrefix:@"_UIBarBackground"] ||
            [child isMemberOfClass:UIView.class]) HGVisitTabDecoration(child, active);
    }
    UIView *custom = HGFindView(view.superview, @"SSTabBar");
    BOOL ownsBackdrop = HGIsClass(view, @"SSTabBar") || !custom || custom.hidden;
    if (active && ownsBackdrop) {
        if (!state.glass) {
            state.glass = [[UIVisualEffectView alloc] initWithEffect:HGMakeGlassEffect()];
            state.glass.userInteractionEnabled = NO;
            state.glass.accessibilityElementsHidden = YES;
            [view insertSubview:state.glass atIndex:0];
        }
        HGApply(^{
            state.glass.frame = view.bounds;
            state.glass.layer.cornerRadius = 27.0;
            state.glass.clipsToBounds = YES;
            view.layer.cornerRadius = 27.0;
            view.clipsToBounds = YES;
        });
    } else {
        [state.glass removeFromSuperview];
        state.glass = nil;
        view.layer.cornerRadius = state.cornerRadius;
        view.clipsToBounds = state.clips;
    }
    // SSTabBar's text buttons live inside a separate UIView row in the supplied dump.
    NSMutableArray<UIView *> *buttons = [NSMutableArray array];
    NSMutableArray<UIView *> *rows = [NSMutableArray array];
    for (UIView *child in view.subviews) {
        if (HGIsClass(child, @"SSTabBarTextButton")) [buttons addObject:child];
        for (UIView *item in child.subviews) {
            if (HGIsClass(item, @"SSTabBarTextButton")) {
                [buttons addObject:item];
                if (![rows containsObject:child]) [rows addObject:child];
            }
        }
    }
    [buttons sortUsingComparator:^NSComparisonResult(UIView *a, UIView *b) {
        return HGHostFrame(a).origin.x < HGHostFrame(b).origin.x ? NSOrderedAscending : NSOrderedDescending;
    }];
    if (active) {
        for (UIView *row in rows) HGSetFrame(row, view.bounds);
        CGFloat width = (CGRectGetWidth(view.bounds) - 12.0) / MAX(1, buttons.count);
        [buttons enumerateObjectsUsingBlock:^(UIView *button, NSUInteger index, BOOL *stop) {
            HGSetFrame(button, CGRectMake(6.0 + width * index, 2.0, width, 50.0));
        }];
    } else {
        for (UIView *row in rows) HGRestoreFrame(row);
        for (UIView *button in buttons) HGRestoreFrame(button);
    }
    state.active = active;
}
void HGInstallFeatures(void) {
    HGInstallChrome();
    HGHookFrame(@"FQVCollectionView", ^CGRect(UIView *view, CGRect frame) { return HGFillParent(view, frame); });
    HGHookControllerLayout(@"FQVShortVideoListViewController", ^(UIViewController *controller) {
        UICollectionView *collection = (id)HGFindView(controller.view, @"FQVCollectionView");
        if (collection) HGLayoutCollection(collection);
    });
    HGHookLayout(@"FQVCollectionView", ^(UIView *view) { HGLayoutCollection((UICollectionView *)view); });
    HGHookLayout(@"FQVShortVideoCell", ^(UIView *view) {
        UICollectionViewCell *cell = (id)view;
        if (HGCanExtend(view)) HGSetFrame(cell.contentView, cell.bounds);
        else HGRestoreFrame(cell.contentView);
    });
    for (NSString *name in @[@"FQVShortVideoPlayerCellView", @"FQVPlayer",
                             @"FQVShortVideoDerivativeVideoControlView", @"SSShortVideoAboveTopControllView",
                             @"SSShortVideoDerivateInfoView"]) {
        HGHookFrame(name, ^CGRect(UIView *view, CGRect frame) { return HGFillParent(view, frame); });
        HGHookLayout(name, ^(UIView *view) {
            HGLayoutFill(view);
            if (HGIsClass(view, @"FQVShortVideoPlayerCellView")) {
                for (UIView *child in view.subviews) {
                    if ([child isMemberOfClass:UIView.class] && HGFindView(child, @"FQVPlayer")) {
                        if (HGCanExtend(view)) HGSetFrame(child, view.bounds);
                        else HGRestoreFrame(child);
                    }
                }
            }
            if (HGIsClass(view, @"FQVPlayer")) {
                NSNumber *originalClip = objc_getAssociatedObject(view, &HGPlayerClipKey);
                if (HGCanExtend(view)) {
                    if (!originalClip) objc_setAssociatedObject(view, &HGPlayerClipKey, @(view.clipsToBounds), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
                    view.clipsToBounds = YES;
                } else if (originalClip) {
                    view.clipsToBounds = originalClip.boolValue;
                    objc_setAssociatedObject(view, &HGPlayerClipKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
                }
            }
        });
    }
    HGHookFrame(@"TTPlayerView", ^CGRect(UIView *view, CGRect frame) {
        if (HGIsClass(view.superview, @"FQVPlayer") && !CGRectIsEmpty(frame)) {
            objc_setAssociatedObject(view, &HGVideoSizeKey, [NSValue valueWithCGSize:frame.size],
                                     OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        }
        CGRect target = HGVideoFrame(view, frame);
        return CGRectIsEmpty(target) ? frame : target;
    });
    HGHookLayout(@"TTPlayerView", ^(UIView *view) {
        if (HGCanExtend(view) && HGIsClass(view.superview, @"FQVPlayer")) {
            CGRect target = HGVideoFrame(view, HGHostFrame(view));
            HGSetFrame(view, target);
        } else HGRestoreFrame(view);
    });
    HGHookFrame(@"FQVShortVideoBaseInsertView", ^CGRect(UIView *view, CGRect frame) { return HGInsertFrame(view, frame); });
    HGHookLayout(@"FQVShortVideoBaseInsertView", ^(UIView *view) {
        if (HGCanExtend(view)) HGSetFrame(view, HGInsertFrame(view, HGHostFrame(view)));
        else HGRestoreFrame(view);
    });
    for (NSString *name in @[@"SSShortVideoDerivateLeftContainerView", @"SSShortVideoAboveLeftContainerView"]) {
        HGHookFrame(name, ^CGRect(UIView *view, CGRect frame) { return HGAnchorBottom(view, frame); });
        HGHookLayout(name, ^(UIView *view) {
            if (HGCanExtend(view)) HGSetFrame(view, HGAnchorBottom(view, HGHostFrame(view)));
            else HGRestoreFrame(view);
        });
    }
    HGHookFrame(@"FQVShortVideoProgressView", ^CGRect(UIView *view, CGRect frame) {
        if (HGCanExtend(view)) frame.origin.y = MAX(0, HGControlBottom(view.superview) - frame.size.height + 5.0);
        return frame;
    });
    HGHookLayout(@"FQVShortVideoProgressView", ^(UIView *view) {
        if (HGCanExtend(view)) {
            CGRect frame = HGHostFrame(view);
            frame.origin.y = MAX(0, HGControlBottom(view.superview) - frame.size.height + 5.0);
            HGSetFrame(view, frame);
        } else HGRestoreFrame(view);
    });
    HGHookFrame(@"FQVShortVideoGradientLayerView", ^CGRect(UIView *view, CGRect frame) {
        if (HGCanExtend(view) && frame.origin.y > 100) frame.origin.y = MAX(0, CGRectGetHeight(view.superview.bounds) - frame.size.height);
        return frame;
    });
    for (NSString *name in @[@"CYLTabBar", @"SSTabBar"]) {
        HGHookFrame(name, ^CGRect(UIView *view, CGRect frame) { return HGTabFrame(view, frame); });
        HGHookLayout(name, ^(UIView *view) { HGLayoutTab(view); });
    }
    HGHookFrame(@"SSTabBarTextButton", ^CGRect(UIView *view, CGRect frame) { return frame; });
    HGHookControllerLayout(@"SSTabBarController", ^(UIViewController *controller) {
        for (NSString *name in @[@"CYLTabBar", @"SSTabBar"]) {
            UIView *bar = HGFindView(controller.view, name);
            if (bar) { HGLayoutTab(bar); [bar setNeedsLayout]; }
        }
    });
}
