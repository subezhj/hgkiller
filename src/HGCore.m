#import "HGCore.h"
#import <math.h>

NSString *const HGPreferencePrefix = @"HGK.v1.";
static NSDictionary *HGPreferences;
static NSUInteger HGMutationDepth;
static NSMutableSet<NSString *> *HGInstalled;
static char HGFrameKey;

@interface HGFrameState : NSObject
@property(nonatomic) CGRect host;
@property(nonatomic) BOOL applied;
@end
@implementation HGFrameState
@end

static NSDictionary *HGDefaults(void) {
    return @{
        @"enabled": @YES,
        @"right.avatar": @YES, @"right.collect": @YES,
        @"right.comment": @YES, @"right.like": @YES, @"right.share": @YES,
        @"right.scale": @0.80,
        @"tab.glass": @YES, @"video.extend": @YES,
        @"video.fillPortrait": @YES,
        @"top.enabled": @YES, @"top.scale": @0.85
    };
}
static void HGReloadPreferences(void) {
    NSMutableDictionary *values = [HGDefaults() mutableCopy];
    for (NSString *key in HGDefaults()) {
        id value = [NSUserDefaults.standardUserDefaults objectForKey:[HGPreferencePrefix stringByAppendingString:key]];
        if ([value isKindOfClass:NSNumber.class]) values[key] = value;
    }
    for (NSString *key in @[@"right.scale", @"top.scale"]) {
        double value = [values[key] doubleValue];
        values[key] = @(isfinite(value) ? MAX(0.55, MIN(1.0, value)) : [HGDefaults()[key] doubleValue]);
    }
    HGPreferences = [values copy];
}
void HGInitializePreferences(void) { HGReloadPreferences(); }
BOOL HGEnabled(void) { return [HGPreferences[@"enabled"] boolValue]; }
BOOL HGBool(NSString *key) { return [HGPreferences[key] boolValue]; }
CGFloat HGNumber(NSString *key) { return [HGPreferences[key] doubleValue]; }

void HGWritePreference(NSString *key, id value) {
    if (!HGDefaults()[key] || ![value isKindOfClass:NSNumber.class]) return;
    [NSUserDefaults.standardUserDefaults setObject:value forKey:[HGPreferencePrefix stringByAppendingString:key]];
    HGReloadPreferences();
    HGRefreshViews();
}
void HGResetPreferences(void) {
    for (NSString *key in HGDefaults()) {
        [NSUserDefaults.standardUserDefaults removeObjectForKey:[HGPreferencePrefix stringByAppendingString:key]];
    }
    HGReloadPreferences();
    HGRefreshViews();
}
BOOL HGIsClass(id object, NSString *name) {
    Class cls = NSClassFromString(name);
    return cls && [object isKindOfClass:cls];
}
UIView *HGFindView(UIView *root, NSString *name) {
    if (HGIsClass(root, name)) return root;
    for (UIView *child in root.subviews) {
        UIView *found = HGFindView(child, name);
        if (found) return found;
    }
    return nil;
}
UIViewController *HGOwner(UIView *view) {
    for (UIResponder *next = view.nextResponder; next; next = next.nextResponder) {
        if ([next isKindOfClass:UIViewController.class]) return (UIViewController *)next;
    }
    return nil;
}
BOOL HGIsFeedView(UIView *view) {
    if (!view.window || view.window.windowLevel != UIWindowLevelNormal) return NO;
    // Restrict to the captured home feed. Search, detail, PiP and landscape windows are excluded.
    for (UIView *node = view; node; node = node.superview) {
        if (HGIsClass(node.nextResponder, @"SSVideoSeriesFeedViewController")) return YES;
    }
    return NO;
}
BOOL HGIsApplying(void) { return HGMutationDepth > 0; }
void HGApply(dispatch_block_t block) {
    HGMutationDepth++;
    @try { block(); } @finally { HGMutationDepth--; }
}
static HGFrameState *HGFrame(UIView *view) {
    HGFrameState *state = objc_getAssociatedObject(view, &HGFrameKey);
    if (!state) {
        state = [HGFrameState new];
        state.host = view.frame;
        objc_setAssociatedObject(view, &HGFrameKey, state, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    return state;
}
CGRect HGHostFrame(UIView *view) { return HGFrame(view).host; }
void HGSetFrame(UIView *view, CGRect frame) {
    if (!view || CGRectIsEmpty(frame) || CGRectIsNull(frame)) return;
    HGFrameState *state = HGFrame(view);
    state.applied = YES;
    if (!CGRectEqualToRect(view.frame, frame)) HGApply(^{ view.frame = frame; });
}
void HGRestoreFrame(UIView *view) {
    HGFrameState *state = objc_getAssociatedObject(view, &HGFrameKey);
    if (!state.applied) return;
    state.applied = NO;
    HGApply(^{ view.frame = state.host; });
}
BOOL HGInstall(Class cls, SEL selector, id (^builder)(IMP)) {
    if (!cls || !selector) return NO;
    if (!HGInstalled) HGInstalled = [NSMutableSet set];
    NSString *key = [NSString stringWithFormat:@"%@/%@", NSStringFromClass(cls), NSStringFromSelector(selector)];
    if ([HGInstalled containsObject:key]) return YES;
    Method method = class_getInstanceMethod(cls, selector);
    if (!method) return NO;
    IMP original = method_getImplementation(method);
    const char *types = method_getTypeEncoding(method);
    IMP replacement = imp_implementationWithBlock(builder(original));
    // Adding an inherited method here prevents replacing its superclass implementation.
    if (!class_addMethod(cls, selector, replacement, types)) {
        method_setImplementation(class_getInstanceMethod(cls, selector), replacement);
    }
    [HGInstalled addObject:key];
    return YES;
}
void HGHookLayout(NSString *name, void (^callback)(UIView *)) {
    SEL selector = @selector(layoutSubviews);
    HGInstall(NSClassFromString(name), selector, ^id(IMP original) {
        return ^(UIView *view) {
            ((void (*)(id, SEL))original)(view, selector);
            if (!HGIsApplying()) callback(view);
        };
    });
}
void HGHookControllerLayout(NSString *name, void (^callback)(UIViewController *)) {
    SEL selector = @selector(viewDidLayoutSubviews);
    HGInstall(NSClassFromString(name), selector, ^id(IMP original) {
        return ^(UIViewController *controller) {
            ((void (*)(id, SEL))original)(controller, selector);
            if (!HGIsApplying()) callback(controller);
        };
    });
}
void HGHookFrame(NSString *name, CGRect (^adjust)(UIView *, CGRect)) {
    SEL selector = @selector(setFrame:);
    HGInstall(NSClassFromString(name), selector, ^id(IMP original) {
        return ^(UIView *view, CGRect frame) {
            if (!HGIsApplying()) {
                HGFrameState *state = HGFrame(view);
                state.host = frame;
                CGRect target = adjust(view, frame);
                state.applied = !CGRectEqualToRect(frame, target);
                frame = target;
            }
            ((void (*)(id, SEL, CGRect))original)(view, selector, frame);
        };
    });
}
static void HGMarkTree(UIView *view) {
    [view setNeedsLayout];
    for (UIView *child in view.subviews) HGMarkTree(child);
}
void HGRefreshViews(void) {
    static BOOL queued;
    if (queued) return;
    queued = YES;
    dispatch_async(dispatch_get_main_queue(), ^{
        queued = NO;
        for (UIScene *scene in UIApplication.sharedApplication.connectedScenes) {
            if (![scene isKindOfClass:UIWindowScene.class]) continue;
            for (UIWindow *window in ((UIWindowScene *)scene).windows) {
                if (window.windowLevel != UIWindowLevelNormal || window.hidden ||
                    !HGIsClass(window.rootViewController, @"SSRootViewController")) continue;
                HGMarkTree(window);
                [window layoutIfNeeded];
            }
        }
    });
}
NSArray<NSString *> *HGMissingClasses(void) {
    NSMutableArray *missing = [NSMutableArray array];
    for (NSString *name in @[@"SSSettingViewController", @"FQVCollectionView",
                            @"FQVShortVideoListViewController", @"FQVPlayer", @"TTPlayerView",
                            @"SSShortVideoRightInteractionView", @"SSTabBar",
                            @"SSVideoSeriesFeedHeaderView"]) {
        if (!NSClassFromString(name)) [missing addObject:name];
    }
    return missing;
}
