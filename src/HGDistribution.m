#import "HGCore.h"
static char HGDistributionKey;
@interface HGDistributionPaint : NSObject
@property(nonatomic, weak) UIView *view;
@property(nonatomic) float opacity;
@property(nonatomic, strong) UIColor *background;
@end
@implementation HGDistributionPaint @end
static void HGDistributionClear(UIView *view, UIView *root, NSMutableArray *saved) {
    if ([view isKindOfClass:UILabel.class] || HGIsClass(view, @"YYLabel")) return;
    BOOL image = [view isKindOfClass:UIImageView.class], effect = [view isKindOfClass:UIVisualEffectView.class];
    BOOL backdrop = (image || effect) && view.bounds.size.width >= root.bounds.size.width * 0.8 && view.bounds.size.height >= 20;
    if (image || effect) { if (!backdrop) return; }
    HGDistributionPaint *paint = nil;
    for (HGDistributionPaint *candidate in saved) if (candidate.view == view) { paint = candidate; break; }
    if (!paint) {
        paint = [HGDistributionPaint new]; paint.view = view; paint.opacity = view.layer.opacity;
        paint.background = view.layer.backgroundColor ? [UIColor colorWithCGColor:view.layer.backgroundColor] : nil; [saved addObject:paint];
    }
    if (view.layer.backgroundColor) view.layer.backgroundColor = nil;
    if (backdrop) { if (view.layer.opacity != 0) view.layer.opacity = 0; return; }
    for (UIView *child in view.subviews) HGDistributionClear(child, root, saved);
}
void HGDistributionAppearance(UIView *view) {
    if (!HGIsClass(view, @"SSShortVideoBottomDistributionView")) return;
    NSMutableArray *saved = objc_getAssociatedObject(view, &HGDistributionKey);
    if (!HGEnabled() || !HGBool(@"distribution.transparent")) {
        for (HGDistributionPaint *paint in saved) { paint.view.layer.opacity = paint.opacity; paint.view.layer.backgroundColor = paint.background.CGColor; }
        objc_setAssociatedObject(view, &HGDistributionKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC); return;
    }
    if (!saved) { saved = [NSMutableArray array]; objc_setAssociatedObject(view, &HGDistributionKey, saved, OBJC_ASSOCIATION_RETAIN_NONATOMIC); }
    // The captured 44 pt insertion wrapper may also supply the solid background.
    UIView *parent = view.superview;
    if (HGIsClass(parent, @"FQVShortVideoBaseInsertView") && fabs(parent.bounds.size.height - view.bounds.size.height) < 1) {
        BOOL found = NO; for (HGDistributionPaint *paint in saved) if (paint.view == parent) found = YES;
        if (!found) { HGDistributionPaint *paint = [HGDistributionPaint new]; paint.view = parent; paint.opacity = parent.layer.opacity; paint.background = parent.layer.backgroundColor ? [UIColor colorWithCGColor:parent.layer.backgroundColor] : nil; [saved addObject:paint]; }
        if (parent.layer.backgroundColor) parent.layer.backgroundColor = nil;
    }
    HGDistributionClear(view, view, saved);
}
