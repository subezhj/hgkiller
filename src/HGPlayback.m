#import "HGCore.h"
BOOL HGPlaybackVisible(UIView *view) {
    UIWindow *window = [view isKindOfClass:UIWindow.class] ? (id)view : view.window;
    if (!window) return NO;
    CGRect visible = CGRectIntersection([view convertRect:view.bounds toView:window], window.bounds);
    for (UIView *node = view; node; node = node.superview) {
        if (node.hidden || node.alpha < 0.01) return NO;
        if (node.clipsToBounds) visible = CGRectIntersection(visible, [node convertRect:node.bounds toView:window]);
    }
    return !CGRectIsNull(visible) && visible.size.width > 1 && visible.size.height > 1;
}
UIView *HGCurrentPicture(UIView *root) {
    if (!HGPlaybackVisible(root)) return nil;
    if (HGIsClass(root, @"FQVShortVideoCell")) {
        CGRect rect = [root convertRect:root.bounds toView:root.window];
        CGRect visible = CGRectIntersection(rect, root.window.bounds);
        CGFloat area = rect.size.width * rect.size.height;
        if (area <= 0 || CGRectIsNull(visible) || visible.size.width * visible.size.height < area * 0.6) return nil;
    }
    if (HGIsClass(root, @"TTPlayerView") && root.bounds.size.width > 100 && root.bounds.size.height > 100) return root;
    for (UIView *child in root.subviews) {
        UIView *found = HGCurrentPicture(child); if (found) return found;
    }
    return nil;
}
