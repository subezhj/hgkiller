#import "HGCore.h"
static char HGLandscapeKey;
static const NSInteger HGLandscapeTag = 0x48474C;
@interface HGLandscapeEntry : NSObject
@property(nonatomic, weak) UIViewController *owner;
@property(nonatomic, strong) UIButton *button;
- (void)activate:(id)sender;
@end

static BOOL HGLandscapeVisible(UIView *view) {
    UIWindow *window = view.window; if (!window) return NO;
    CGRect visible = CGRectIntersection([view convertRect:view.bounds toView:window], window.bounds);
    for (UIView *node = view; node; node = node.superview) {
        if (node.hidden || node.alpha < 0.01) return NO;
        if (node.clipsToBounds) visible = CGRectIntersection(visible, [node convertRect:node.bounds toView:window]);
    }
    return !CGRectIsNull(visible) && visible.size.width > 1 && visible.size.height > 1;
}
static BOOL HGCurrentVideoCell(UIView *cell, UIView *root) {
    if (cell.hidden || !cell.window) return NO;
    CGRect rect = [cell convertRect:cell.bounds toView:root];
    CGFloat area = rect.size.width * rect.size.height;
    CGRect visible = CGRectIntersection(rect, root.bounds);
    for (UIView *node = cell.superview; node && node != root; node = node.superview)
        if (node.clipsToBounds) visible = CGRectIntersection(visible, [node convertRect:node.bounds toView:root]);
    return area > 0 && !CGRectIsNull(visible) && visible.size.width * visible.size.height / area > 0.6;
}
static BOOL HGLandscapeWords(NSString *string, BOOL label) {
    NSString *text = string.lowercaseString;
    for (NSString *word in @[@"exit", @"dismiss", @"close", @"portrait", @"cancel", @"退出", @"关闭"])
        if ([text containsString:word]) return NO;
    if (label) return [text containsString:@"横屏"] || [text containsString:@"全屏播放"] || [text containsString:@"全屏观看"] || [text isEqualToString:@"全屏"];
    for (NSString *word in @[@"landscape", @"horizontal", @"fullscreen", @"full_screen"])
        if ([text containsString:word]) return YES;
    return NO;
}
// Red Fruit uses an independent UILabel inside its 88 x 28 native button,
// rather than UIButton.currentTitle (FLEX dump 1792331057).
static NSString *HGLandscapeControlText(UIView *view) {
    NSMutableArray<NSString *> *parts = [NSMutableArray array];
    if (view.accessibilityLabel.length) [parts addObject:view.accessibilityLabel];
    if ([view isKindOfClass:UILabel.class]) {
        UILabel *label = (id)view;
        NSString *text = label.text ?: label.attributedText.string;
        if (text.length) [parts addObject:text];
    }
    if ([view isKindOfClass:UIButton.class]) {
        UIButton *button = (id)view;
        NSString *text = button.currentTitle ?: button.currentAttributedTitle.string;
        if (text.length) [parts addObject:text];
    }
    for (UIView *child in view.subviews) {
        // A nested control owns its own action; its label cannot identify its parent.
        if ([child isKindOfClass:UIControl.class]) continue;
        NSString *text = HGLandscapeControlText(child);
        if (text.length) [parts addObject:text];
    }
    return [parts componentsJoinedByString:@" "];
}
static BOOL HGLandscapeInactiveContainer(UIView *view) {
    return (HGIsClass(view, @"FQVShortVideoVPlayerOutterMultiSeriesControlView") ||
            HGIsClass(view, @"FQVShortVideoVPlayerSingleSeriesControlView") ||
            HGIsClass(view, @"FQVShortVideoDerivativeVideoControlView")) && (view.hidden || view.alpha < 0.01);
}
static UIControl *HGFindLandscape(UIView *view, UIView *root, UIControlEvents *event, NSMutableArray<NSString *> *log) {
    if (view.tag == HGLandscapeTag || HGLandscapeInactiveContainer(view) || (HGIsClass(view, @"FQVShortVideoCell") && !HGCurrentVideoCell(view, root))) return nil;
    if ([view isKindOfClass:UIControl.class]) {
        UIControl *control = (id)view;
        NSString *label = HGLandscapeControlText(view);
        for (NSNumber *number in @[@(UIControlEventTouchUpInside), @(UIControlEventPrimaryActionTriggered)]) {
            UIControlEvents candidate = number.unsignedIntegerValue;
            if (!(control.allControlEvents & candidate)) continue;
            BOOL match = HGLandscapeWords([label stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceCharacterSet], YES);
            BOOL forbidden = NO, bound = NO;
            for (id target in control.allTargets) {
                if ([target isKindOfClass:HGLandscapeEntry.class]) continue;
                for (NSString *action in [control actionsForTarget:target == NSNull.null ? nil : target forControlEvent:candidate]) {
                    bound = YES;
                    if (log.count < 40) [log addObject:[NSString stringWithFormat:@"%@ → %@ %@", NSStringFromClass(control.class), target == NSNull.null ? @"responder" : NSStringFromClass([target class]), action]];
                    if (HGLandscapeWords(action, NO)) match = YES;
                    NSString *lower = action.lowercaseString;
                    for (NSString *word in @[@"exit", @"dismiss", @"close", @"portrait", @"cancel"])
                        if ([lower containsString:word]) forbidden = YES;
                }
            }
            if (match && bound && !forbidden) {
                [log addObject:[NSString stringWithFormat:@"选中原生按钮：%@ text=%@ frame=%@ hidden=%@", NSStringFromClass(control.class), label, NSStringFromCGRect(control.frame), control.hidden ? @"YES" : @"NO"]];
                *event = candidate; return control;
            }
        }
    }
    for (UIView *child in view.subviews) {
        UIControl *match = HGFindLandscape(child, root, event, log); if (match) return match;
    }
    return nil;
}
// Keep the supplemental entry in window coordinates. Cell scroll offsets, aspect-fit
// picture frames, captions and delayed native button layout must not move this entry.
static CGRect HGLandscapeButtonFrame(UIView *root) {
    UIWindow *window = root.window;
    CGRect visible = CGRectIntersection(root.bounds, [root convertRect:window.bounds fromView:window]);
    CGFloat width = MIN(96, visible.size.width - 32), height = 36;
    CGFloat top = MAX(CGRectGetMinY(visible) + 12, [root convertPoint:CGPointMake(0, window.safeAreaInsets.top + 64) fromView:window].y);
    CGFloat bottom = MIN(CGRectGetMaxY(visible) - 12, [root convertPoint:CGPointMake(0, window.bounds.size.height - window.safeAreaInsets.bottom - 110) fromView:window].y);
    if (CGRectIsNull(visible) || width < 44 || bottom - top < height) return CGRectNull;
    CGPoint anchor = [root convertPoint:CGPointMake(CGRectGetMidX(window.bounds), CGRectGetMinY(window.bounds) + window.bounds.size.height * 0.60) fromView:window];
    CGFloat x = MAX(CGRectGetMinX(visible) + 16, MIN(anchor.x - width / 2, CGRectGetMaxX(visible) - width - 16));
    CGFloat y = MAX(top, MIN(anchor.y, bottom - height));
    return CGRectMake(x, y, width, height);
}
static void HGLandscapeRecord(NSString *text) {
    [NSUserDefaults.standardUserDefaults setObject:[NSString stringWithFormat:@"hgkiller 0.1.37\n%@\n%@", NSDate.date, text] forKey:[HGPreferencePrefix stringByAppendingString:@"landscape.lastDiagnostic"]];
}
NSString *HGLandscapeDiagnosticText(void) {
    return [NSUserDefaults.standardUserDefaults stringForKey:[HGPreferencePrefix stringByAppendingString:@"landscape.lastDiagnostic"]] ?: @"尚未点击补充横屏入口。";
}
@implementation HGLandscapeEntry
- (void)activate:(id)sender {
    UIViewController *owner = self.owner;
    UIView *picture = HGCurrentPicture(owner.view);
    if (!HGEnabled() || !HGBool(@"landscape.enabled") || !owner.view.window || !picture || picture.bounds.size.width <= picture.bounds.size.height) return;
    HGRestoreVideoExperiment();
    NSMutableArray *log = [NSMutableArray array]; UIControlEvents event = 0;
    UIControl *native = HGFindLandscape(owner.view, owner.view, &event, log);
    if (!native) {
        HGLandscapeRecord([@"当前视频未发现已绑定的原生横屏按钮。\n" stringByAppendingString:[log componentsJoinedByString:@"\n"]]);
        if (!owner.presentedViewController) {
            UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"原生横屏入口未找到" message:@"当前视频没有可识别的原生按钮事件。请在“诊断与重置 → 横屏入口诊断”查看记录；有原生按钮时的 FLEX 控件 target/action 信息可用于补充适配。" preferredStyle:UIAlertControllerStyleAlert];
            [alert addAction:[UIAlertAction actionWithTitle:@"好" style:UIAlertActionStyleDefault handler:nil]]; [owner presentViewController:alert animated:YES completion:nil];
        }
        return;
    }
    HGLandscapeRecord([NSString stringWithFormat:@"已发送当前视频原生按钮事件：%@\n%@", NSStringFromClass(native.class), [log componentsJoinedByString:@"\n"]]);
    [native sendActionsForControlEvents:event];
    __weak UIViewController *weakOwner = owner;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, NSEC_PER_SEC), dispatch_get_main_queue(), ^{
        UIWindow *window = weakOwner.viewIfLoaded.window;
        if (window && (window.bounds.size.width > window.bounds.size.height || UIInterfaceOrientationIsLandscape(window.windowScene.interfaceOrientation)))
            HGLandscapeRecord(@"已调用原生按钮，并观测到横屏。" );
    });
}
@end
void HGRefreshLandscape(UIViewController *controller) {
    if (!HGIsClass(controller, @"FQVShortVideoListViewController") || !controller.isViewLoaded) return;
    UIView *view = controller.view; UIWindow *window = view.window;
    HGLandscapeEntry *state = objc_getAssociatedObject(controller, &HGLandscapeKey);
    UIView *picture = HGCurrentPicture(view);
    BOOL enabled = HGEnabled() && HGBool(@"landscape.enabled") && picture && picture.bounds.size.width > picture.bounds.size.height && window && window.windowLevel == UIWindowLevelNormal && window.bounds.size.height > window.bounds.size.width && HGLandscapeVisible(view);
    if (!enabled) { [state.button removeFromSuperview]; return; }
    if (!state) {
        state = [HGLandscapeEntry new]; state.owner = controller;
        state.button = [UIButton buttonWithType:UIButtonTypeSystem]; state.button.tag = HGLandscapeTag;
        [state.button setTitle:@"全屏观看" forState:UIControlStateNormal]; [state.button setTitleColor:UIColor.whiteColor forState:UIControlStateNormal];
        state.button.titleLabel.font = [UIFont systemFontOfSize:14 weight:UIFontWeightSemibold];
        state.button.backgroundColor = [UIColor.blackColor colorWithAlphaComponent:0.4]; state.button.layer.cornerRadius = 16;
        state.button.accessibilityLabel = @"调用红果原生横屏播放";
        [state.button addTarget:state action:@selector(activate:) forControlEvents:UIControlEventTouchUpInside];
        objc_setAssociatedObject(controller, &HGLandscapeKey, state, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    if (state.button.superview != view) [view addSubview:state.button];
    UIControlEvents event = 0; NSMutableArray *log = [NSMutableArray array];
    UIControl *native = HGFindLandscape(view, view, &event, log);
    CGRect rect = HGLandscapeButtonFrame(view);
    if (CGRectIsNull(rect)) { [state.button removeFromSuperview]; return; }
    if (!CGRectEqualToRect(state.button.frame, rect)) state.button.frame = rect;
    BOOL nativeVisible = native && native.enabled && HGLandscapeVisible(native) && CGRectIntersectsRect([native convertRect:native.bounds toView:view], view.bounds);
    if (state.button.hidden != nativeVisible) state.button.hidden = nativeVisible;
    if (view.subviews.lastObject != state.button) [view bringSubviewToFront:state.button];
}
