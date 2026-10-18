#import "HGCore.h"
#import <QuartzCore/QuartzCore.h>

@interface HGHeightBurst : NSObject
@property(nonatomic) CFTimeInterval start;
@property(nonatomic) NSUInteger count;
@property(nonatomic) BOOL captured;
@end
@implementation HGHeightBurst @end
static NSMutableDictionary<NSString *, HGHeightBurst *> *HGHeightBursts;
static NSString *HGHeightTraceKey(void) { return [HGPreferencePrefix stringByAppendingString:@"height.lastTrace"]; }
void HGHeightBeginAttempt(void) {
    HGHeightBursts = [NSMutableDictionary dictionary];
    NSString *message = [NSString stringWithFormat:@"hgkiller 0.1.26 · 仅底栏诊断\n时间：%@\n高度：%.0f pt\n播放列表、分页、播放器尺寸保持原生。\n布局诊断只记录，不会自动关闭功能。", NSDate.date, HGNumber(@"tab.appearance.height")];
    [NSUserDefaults.standardUserDefaults setObject:message forKey:[HGPreferencePrefix stringByAppendingString:@"height.lastAttempt"]];
    [NSUserDefaults.standardUserDefaults synchronize];
}
void HGRecordHeightLayout(id object, SEL selector) {
    if (!HGEnabled() || !HGBool(@"tab.layout.enabled")) return;
    BOOL tracked = NO;
    for (NSString *name in @[@"SSTabBar", @"SSTabBarController", @"FQVShortVideoListViewController", @"SSTabBarTextButton"])
        if (HGIsClass(object, name)) { tracked = YES; break; }
    if (!tracked) return;
    if (!HGHeightBursts) HGHeightBursts = [NSMutableDictionary dictionary];
    NSString *key = [NSString stringWithFormat:@"%@ %@", NSStringFromClass([object class]), NSStringFromSelector(selector)];
    HGHeightBurst *burst = HGHeightBursts[key];
    if (!burst) { burst = [HGHeightBurst new]; HGHeightBursts[key] = burst; }
    CFTimeInterval now = CACurrentMediaTime();
    if (now - burst.start > 0.25) { burst.start = now; burst.count = 0; }
    burst.count++;
    if (burst.count < 120 || burst.captured) return;
    burst.captured = YES;
    UIView *view = [object isKindOfClass:UIView.class] ? object : nil;
    NSArray<NSString *> *symbols = NSThread.callStackSymbols;
    if (symbols.count > 24) symbols = [symbols subarrayWithRange:NSMakeRange(0, 24)];
    NSString *trace = [NSString stringWithFormat:@"hgkiller 0.1.26 · 仅底栏诊断\n时间：%@\n%@ 在 250 ms 内进入 %lu 次\nframe：%@\nbounds：%@\n\n%@",
                       NSDate.date, key, (unsigned long)burst.count, view ? NSStringFromCGRect(view.frame) : @"控制器", view ? NSStringFromCGRect(view.bounds) : @"控制器", [symbols componentsJoinedByString:@"\n"]];
    // Capture once per method per attempt. No setNeedsLayout, frame writes, or pause/disable action.
    [NSUserDefaults.standardUserDefaults setObject:trace forKey:HGHeightTraceKey()];
    [NSUserDefaults.standardUserDefaults synchronize];
    NSLog(@"%@", trace);
}
NSString *HGHeightDiagnosticText(void) {
    NSUserDefaults *defaults = NSUserDefaults.standardUserDefaults;
    NSString *attempt = [defaults stringForKey:[HGPreferencePrefix stringByAppendingString:@"height.lastAttempt"]] ?: @"尚未开启底栏高度诊断。";
    NSString *trace = [defaults stringForKey:HGHeightTraceKey()] ?: @"尚未记录到高频重复布局；这不代表已排除其他卡死原因。";
    return [NSString stringWithFormat:@"%@\n\n最近捕获的异常（可能来自较早尝试）：\n%@", attempt, trace];
}
