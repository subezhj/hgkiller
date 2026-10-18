#import "HGCore.h"
#import <math.h>

NSString *const HGPreferencePrefix = @"HGK.v1.";
NSString *const HGPreferencesDidChangeNotification = @"HGKPreferencesDidChange";
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
    NSMutableDictionary *defaults = [@{
        @"enabled": @YES,
        @"right.avatar": @YES, @"right.collect": @YES,
        @"right.comment": @YES, @"right.like": @YES, @"right.share": @YES,
        @"right.scale": @0.80, @"right.gap": @6.0,
        @"tab.textScale": @1.0, @"tab.appearance.enabled": @NO, @"tab.layout.enabled": @NO, @"tab.appearance.height": @84.0, @"video.extend": @NO,
        @"video.fillPortrait": @NO,
        @"tab.liquid.enabled": @NO, @"tab.liquid.video": @NO,
        @"caption.enabled": @YES, @"caption.titleScale": @1.0, @"caption.descriptionScale": @1.0,
        @"top.enabled": @YES, @"top.scale": @0.85,
        @"profiles.enabled": @NO, @"landscape.enabled": @NO,
        @"clean.enabled": @NO, @"clean.right": @YES, @"clean.caption": @YES, @"clean.header": @YES, @"clean.distribution": @NO,
        @"shade.enabled": @NO, @"shade.top": @1.0, @"shade.bottom": @1.0
    } mutableCopy];
    for (NSString *key in defaults.allKeys.copy)
        if ([key hasPrefix:@"right."] || [key hasPrefix:@"caption."] || [key hasPrefix:@"clean."] || [key hasPrefix:@"shade."])
            defaults[[@"detail." stringByAppendingString:key]] = defaults[key];
    return defaults;
}
static void HGReloadPreferences(void) {
    NSMutableDictionary *values = [HGDefaults() mutableCopy];
    for (NSString *key in HGDefaults()) {
        id value = [NSUserDefaults.standardUserDefaults objectForKey:[HGPreferencePrefix stringByAppendingString:key]];
        if ([value isKindOfClass:NSNumber.class]) values[key] = value;
    }
    for (NSString *key in @[@"right.scale", @"top.scale", @"caption.titleScale", @"caption.descriptionScale"]) {
        double value = [values[key] doubleValue];
        values[key] = @(isfinite(value) ? MAX(0.55, MIN(1.0, value)) : [HGDefaults()[key] doubleValue]);
    }
    double appearanceHeight = [values[@"tab.appearance.height"] doubleValue];
    values[@"tab.appearance.height"] = @(isfinite(appearanceHeight) ? MAX(62, MIN(84, appearanceHeight)) : 84);
    double gap = [values[@"right.gap"] doubleValue]; values[@"right.gap"] = @(isfinite(gap) ? MAX(0, MIN(24, gap)) : 6);
    double text = [values[@"tab.textScale"] doubleValue]; values[@"tab.textScale"] = @(isfinite(text) ? MAX(0.55, MIN(1.2, text)) : 1);
    for (NSString *key in values.allKeys.copy) {
        NSString *base = [key hasPrefix:@"detail."] ? [key substringFromIndex:7] : key;
        double value = [values[key] doubleValue];
        if ([base isEqualToString:@"right.scale"] || ([base hasPrefix:@"caption."] && [base hasSuffix:@"Scale"]))
            values[key] = @(isfinite(value) ? MAX(0.55, MIN(1, value)) : [HGDefaults()[key] doubleValue]);
        if ([base isEqualToString:@"right.gap"]) values[key] = @(isfinite(value) ? MAX(0, MIN(24, value)) : 6);
        if ([base isEqualToString:@"shade.top"] || [base isEqualToString:@"shade.bottom"])
            values[key] = @(isfinite(value) ? MAX(0, MIN(1, value)) : 1);
    }
    // Do not honor old saved fullscreen values in this hotfix; the corresponding hooks are absent.
    values[@"video.extend"] = @NO;
    values[@"video.fillPortrait"] = @NO;
    HGPreferences = [values copy];
}
static char HGLayoutBurstKey;
static BOOL HGSafetyTripped;
static NSUInteger HGMonitoringGeneration;
@interface HGLayoutBurst : NSObject
@property(nonatomic) CFTimeInterval start;
@property(nonatomic) NSUInteger count;
@property(nonatomic) NSUInteger generation;
@end
@implementation HGLayoutBurst
@end
BOOL HGSafetyPaused(void) { return HGSafetyTripped; }
void HGClearSafetyRecord(void) {
    [NSUserDefaults.standardUserDefaults removeObjectForKey:[HGPreferencePrefix stringByAppendingString:@"safety.lastReason"]];
    HGRefreshViews();
}
NSString *HGSafetyReason(void) {
    return [NSUserDefaults.standardUserDefaults stringForKey:[HGPreferencePrefix stringByAppendingString:@"safety.lastReason"]] ?: @"";
}
static BOOL HGObserveLayout(id object, SEL selector) { HGRecordHeightLayout(object, selector); return YES; } // Records only; protection remains disabled.

void HGInitializePreferences(void) {
    // Every diagnostic launch starts off so a prior hang does not prevent reading its record.
    NSUserDefaults *defaults = NSUserDefaults.standardUserDefaults;
    [defaults setBool:NO forKey:[HGPreferencePrefix stringByAppendingString:@"tab.layout.enabled"]];
    HGReloadPreferences();
}
BOOL HGEnabled(void) { return !HGSafetyTripped && [HGPreferences[@"enabled"] boolValue]; }
BOOL HGBool(NSString *key) { return [key isEqualToString:@"enabled"] ? HGEnabled() : [HGPreferences[key] boolValue]; }
CGFloat HGNumber(NSString *key) { return [HGPreferences[key] doubleValue]; }

void HGWritePreference(NSString *key, id value) {
    if (!HGDefaults()[key] || ![value isKindOfClass:NSNumber.class]) return;
    if ([key isEqualToString:@"profiles.enabled"] && [value boolValue]) {
        for (NSString *detailKey in HGDefaults()) if ([detailKey hasPrefix:@"detail."]) {
            NSString *stored = [HGPreferencePrefix stringByAppendingString:detailKey];
            if (![NSUserDefaults.standardUserDefaults objectForKey:stored])
                [NSUserDefaults.standardUserDefaults setObject:HGPreferences[[detailKey substringFromIndex:7]] forKey:stored];
        }
    }
    if ([key isEqualToString:@"enabled"] && [value boolValue]) {
        HGSafetyTripped = NO; HGMonitoringGeneration++; // Explicit user retry; keep historical reason.
    }
    [NSUserDefaults.standardUserDefaults setObject:value forKey:[HGPreferencePrefix stringByAppendingString:key]];
    HGReloadPreferences();
    if ([key isEqualToString:@"tab.layout.enabled"] && [value boolValue]) HGHeightBeginAttempt();
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
    if (fabs(view.frame.origin.x - frame.origin.x) > 0.1 || fabs(view.frame.origin.y - frame.origin.y) > 0.1 ||
        fabs(view.frame.size.width - frame.size.width) > 0.1 || fabs(view.frame.size.height - frame.size.height) > 0.1)
        HGApply(^{ view.frame = frame; });
}
void HGRestoreFrame(UIView *view) {
    HGFrameState *state = objc_getAssociatedObject(view, &HGFrameKey);
    if (!state.applied) return;
    state.applied = NO;
    if (!CGRectEqualToRect(view.frame, state.host)) HGApply(^{ view.frame = state.host; });
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
            BOOL observe = HGObserveLayout(view, selector);
            ((void (*)(id, SEL))original)(view, selector);
            if (!HGIsApplying() && (observe || !HGEnabled())) callback(view);
        };
    });
}
void HGHookControllerLayout(NSString *name, void (^callback)(UIViewController *)) {
    SEL selector = @selector(viewDidLayoutSubviews);
    HGInstall(NSClassFromString(name), selector, ^id(IMP original) {
        return ^(UIViewController *controller) {
            HGObserveLayout(controller, selector);
            ((void (*)(id, SEL))original)(controller, selector);
            if (!HGIsApplying()) callback(controller);
        };
    });
}
void HGHookFrame(NSString *name, CGRect (^adjust)(UIView *, CGRect)) {
    SEL selector = @selector(setFrame:);
    HGInstall(NSClassFromString(name), selector, ^id(IMP original) {
        return ^(UIView *view, CGRect frame) {
            HGObserveLayout(view, selector);
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
static void HGMarkTargets(UIView *view) {
    if ((!HGEnabled() || !HGBool(@"tab.liquid.enabled") || !HGBool(@"tab.liquid.video"))) HGRestoreVideoExperiment();
    if (HGIsClass(view.nextResponder, @"FQVShortVideoListViewController")) HGRefreshLandscape((id)view.nextResponder);
    for (NSString *name in @[@"SSShortVideoRightInteractionView", @"SSTabBar", @"SSTabBarTextButton",
                            @"SSVideoSeriesFeedHeaderView", @"SSShortVideoOutterSeriesLeftContainerView", @"SSShortVideoSingleSeriesInfoLeftContainerView",
                            @"SSShortVideoBottomDistributionView", @"FQVShortVideoGradientLayerView"]) {
        if (HGIsClass(view, name)) { HGApplyViewing(view); [view setNeedsLayout]; break; }
    }
    for (UIView *child in view.subviews) HGMarkTargets(child);
}
void HGRefreshViews(void) {
    static BOOL queued;
    if (queued) return;
    queued = YES;
    dispatch_async(dispatch_get_main_queue(), ^{
        queued = NO;
        NSMutableArray<UIWindow *> *windows = [NSMutableArray array];
        for (UIScene *scene in UIApplication.sharedApplication.connectedScenes) {
            if (![scene isKindOfClass:UIWindowScene.class]) continue;
            [windows addObjectsFromArray:((UIWindowScene *)scene).windows];
        }
        // Legacy AppDelegate apps may have no connected UIScene.
        for (UIWindow *window in UIApplication.sharedApplication.windows) {
            if (![windows containsObject:window]) [windows addObject:window];
        }
        for (UIWindow *window in windows) {
            if (window.windowLevel != UIWindowLevelNormal || window.hidden ||
                !HGIsClass(window.rootViewController, @"SSRootViewController")) continue;
            HGMarkTargets(window);
        }
        [NSNotificationCenter.defaultCenter postNotificationName:HGPreferencesDidChangeNotification object:nil];
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









