#import "HGCore.h"
#import "HGGeometry.h"

void HGInstallChrome(void);
static char HGVideoSizeKey, HGInsertRoleKey, HGPlayerClipKey;
void HGInstallTabBar(void);
BOOL HGFeedExtensionOn(UIView *view);
void HGUpdateFeedCollection(UICollectionView *collection);

static CGRect HGCGRect(HGRect r) { return CGRectMake(r.x, r.y, r.width, r.height); }
static BOOL HGCanExtend(UIView *view) { return HGFeedExtensionOn(view); }
static CGRect HGFillParent(UIView *view, CGRect frame) {
    if (!HGCanExtend(view) || !view.superview || CGRectIsEmpty(view.superview.bounds)) return frame;
    return CGRectMake(0, 0, CGRectGetWidth(view.superview.bounds), CGRectGetHeight(view.superview.bounds));
}
static void HGLayoutFill(UIView *view) {
    if (HGCanExtend(view)) HGSetFrame(view, HGFillParent(view, HGHostFrame(view)));
    else HGRestoreFrame(view);
}
static void HGLayoutCollection(UICollectionView *collection) { HGUpdateFeedCollection(collection); }
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
        screenBottom = HGGlassRectWithHeight(CGRectGetWidth(window.bounds), CGRectGetHeight(window.bounds),
                                  window.safeAreaInsets.bottom, HGNumber(@"tab.height")).y - 12.0;
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
                             @"FQVShortVideoDerivativeVideoControlView", @"FQVShortVideoVPlayerOutterMultiSeriesControlView", @"SSShortVideoAboveTopControllView",
                             @"SSShortVideoDerivateInfoView", @"SSShortVideoOutterSeriesInfoView"]) {
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
    for (NSString *name in @[@"SSShortVideoDerivateLeftContainerView", @"SSShortVideoAboveLeftContainerView", @"SSShortVideoOutterSeriesLeftContainerView"]) {
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
    HGInstallTabBar();
}
