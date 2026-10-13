#import <UIKit/UIKit.h>
#import "HGCore.h"
#import "HGGeometry.h"
#import <math.h>

static NSUInteger HGBarPasses, HGRightPasses, HGChecks, HGSteadyRightPasses, HGButtonPasses, HGSteadyButtonPasses;
static BOOL HGDidTripSafety;
static IMP HGFeedFrameBeforeLoad, HGPlayerFrameBeforeLoad, HGItemBeforeLoad, HGSizeBeforeLoad, HGButtonFrameBeforeLoad;
static void HGFinish(NSString *error) {
    NSString *path = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES).firstObject
                      stringByAppendingPathComponent:@"hg-results.json"];
    NSDictionary *result = @{@"success": @(!error), @"checks": @(HGChecks),
                             @"tabLayoutPasses": @(HGBarPasses), @"rightLayoutPasses": @(HGRightPasses),
                             @"error": error ?: @"", @"steadyRightLayoutPasses": @(HGSteadyRightPasses), @"safetyTripped": @(HGDidTripSafety), @"recoveredEnabled": @(HGEnabled()), @"currentSafetyPaused": @(HGSafetyPaused()), @"buttonLayoutPasses": @(HGButtonPasses), @"steadyButtonLayoutPasses": @(HGSteadyButtonPasses)};
    [[NSJSONSerialization dataWithJSONObject:result options:NSJSONWritingPrettyPrinted error:nil] writeToFile:path atomically:YES];
}
static void HGCheck(BOOL condition, NSString *message) {
    HGChecks++;
    if (!condition) @throw [NSException exceptionWithName:@"HGRegressionFailure" reason:message userInfo:nil];
}
static BOOL closeTo(CGFloat a, CGFloat b) { return fabs(a - b) < 0.3; }

static CGFloat HGVisualY(UIView *view) { return view.center.y + view.layer.sublayerTransform.m42; }
static BOOL rectClose(CGRect a, CGRect b) {
    return fabs(a.origin.x - b.origin.x) < 0.01 && fabs(a.origin.y - b.origin.y) < 0.01 &&
           fabs(a.size.width - b.size.width) < 0.01 && fabs(a.size.height - b.size.height) < 0.01;
}
static void HGWriteProgress(NSInteger phase) {
    NSString *path = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES).firstObject
                      stringByAppendingPathComponent:@"hg-progress.json"];
    NSDictionary *info = @{@"phase": @(phase), @"buttons": @(HGButtonPasses), @"enabled": @(HGEnabled()),
                           @"paused": @(HGSafetyPaused()), @"reason": HGSafetyReason()};
    [[NSJSONSerialization dataWithJSONObject:info options:NSJSONWritingPrettyPrinted error:nil] writeToFile:path atomically:YES];
}
@interface SSRootViewController : UIViewController @end
@implementation SSRootViewController @end
@interface SSVideoSeriesFeedViewController : UIViewController @end
@implementation SSVideoSeriesFeedViewController @end
@interface FQVShortVideoListViewController : UIViewController @end
@implementation FQVShortVideoListViewController @end
@interface SSVideoSeriesFeedHeaderView : UIView @end
@implementation SSVideoSeriesFeedHeaderView @end
@interface FQVCollectionView : UICollectionView @end
@implementation FQVCollectionView @end
@interface FQVShortVideoCell : UICollectionViewCell @end
@implementation FQVShortVideoCell @end
@interface FQVPlayer : UIView @end
@implementation FQVPlayer @end

@interface HGFixtureLayout : UICollectionViewLayout @end
@implementation HGFixtureLayout
- (CGSize)collectionViewContentSize { return CGSizeMake(self.collectionView.bounds.size.width, 784.0 * 3); }
- (UICollectionViewLayoutAttributes *)layoutAttributesForItemAtIndexPath:(NSIndexPath *)path {
    UICollectionViewLayoutAttributes *a = [UICollectionViewLayoutAttributes layoutAttributesForCellWithIndexPath:path];
    a.frame = CGRectMake(0, path.item * 784.0, self.collectionView.bounds.size.width, 784.0);
    return a;
}
- (NSArray *)layoutAttributesForElementsInRect:(CGRect)rect {
    NSMutableArray *result = [NSMutableArray array];
    for (NSInteger item = 0; item < 3; item++) {
        UICollectionViewLayoutAttributes *a = [self layoutAttributesForItemAtIndexPath:[NSIndexPath indexPathForItem:item inSection:0]];
        if (CGRectIntersectsRect(a.frame, rect)) [result addObject:a];
    }
    return result;
}
@end

@interface SSTabBarTextButton : UIControl
@property(nonatomic, strong) UIView *caption;
@property(nonatomic, strong) UILabel *label;
@end
@implementation SSTabBarTextButton
- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        self.caption = [[UIView alloc] initWithFrame:CGRectMake(49.6667, 13.6667, 32, 22.6667)];
        self.label = [[UILabel alloc] initWithFrame:self.caption.bounds];
        self.label.text = @"首页";
        [self.caption addSubview:self.label]; [self addSubview:self.caption];
    }
    return self;
}
- (void)layoutSubviews {
    [super layoutSubviews];
    HGButtonPasses++;
    CGRect native = CGRectMake(49.6667, 13.6667, 32, 22.6667);
    // Adversarial host: reject plugin geometry writes and request another layout until native constraints match.
    if (!rectClose(self.caption.frame, native) || !closeTo(self.bounds.size.width, 131.3333)) [self setNeedsLayout];
    self.caption.frame = native;
}
@end
@interface CYLTabBar : UIView @end
@implementation CYLTabBar @end
@interface SSTabBar : UIView
@property(nonatomic, strong) UIVisualEffectView *oldBlur;
@property(nonatomic, strong) UIImageView *oldImage;
@property(nonatomic, strong) UIView *row;
@property(nonatomic, strong) NSArray<SSTabBarTextButton *> *buttons;
@end
@implementation SSTabBar
- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        self.oldBlur = [[UIVisualEffectView alloc] initWithEffect:[UIBlurEffect effectWithStyle:UIBlurEffectStyleDark]];
        self.oldBlur.frame = CGRectMake(0, 0, 402, 84);
        self.oldImage = [[UIImageView alloc] initWithFrame:CGRectMake(0, 0, 402, 84)];
        self.oldImage.backgroundColor = UIColor.grayColor;
        self.row = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 402, 49.6667)];
        [self addSubview:self.oldBlur]; [self addSubview:self.oldImage]; [self addSubview:self.row];
        NSMutableArray *buttons = [NSMutableArray array];
        for (NSUInteger index = 0; index < 3; index++) {
            SSTabBarTextButton *button = [[SSTabBarTextButton alloc] initWithFrame:CGRectMake(index * 135.3333, 0, 131.3333, 49.6667)];
            [self.row addSubview:button]; [buttons addObject:button];
        }
        self.buttons = buttons;
    }
    return self;
}
- (void)layoutSubviews {
    HGBarPasses++;
    [super layoutSubviews];
    self.oldBlur.frame = CGRectMake(0, 0, 402, 84);
    self.oldImage.frame = CGRectMake(0, 0, 402, 84);
    self.row.frame = CGRectMake(0, 0, 402, 49.6667);
    for (NSUInteger index = 0; index < self.buttons.count; index++) {
        self.buttons[index].frame = CGRectMake(index * 135.3333, 0, 131.3333, 49.6667);
    }
}
@end

@interface HGFixtureRightItem : UIView @end
@implementation HGFixtureRightItem
- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        UIView *icon = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 46, 46)];
        icon.backgroundColor = UIColor.whiteColor;
        UILabel *text = [[UILabel alloc] initWithFrame:CGRectMake(0, 46, 46, 16)];
        text.text = @"收藏"; [self addSubview:icon]; [self addSubview:text];
    }
    return self;
}
@end
@interface SSShortVideoRightInteractionAvatarView : HGFixtureRightItem @end
@implementation SSShortVideoRightInteractionAvatarView @end
@interface SSShortVideoRightInteractionCollectView : HGFixtureRightItem @end
@implementation SSShortVideoRightInteractionCollectView @end
@interface SSShortVideoRightInteractionCommentView : HGFixtureRightItem @end
@implementation SSShortVideoRightInteractionCommentView @end
@interface SSShortVideoRightInteractionLikeView : HGFixtureRightItem @end
@implementation SSShortVideoRightInteractionLikeView @end
@interface SSShortVideoRightInteractionShareView : HGFixtureRightItem @end
@implementation SSShortVideoRightInteractionShareView @end
@interface SSShortVideoRightInteractionView : UIView
@property(nonatomic, strong) NSArray<UIView *> *items;
@end
@implementation SSShortVideoRightInteractionView
- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        NSMutableArray *items = [NSMutableArray array];
        NSArray *names = @[@"SSShortVideoRightInteractionCollectView", @"SSShortVideoRightInteractionCommentView",
                           @"SSShortVideoRightInteractionLikeView", @"SSShortVideoRightInteractionShareView"];
        for (NSUInteger index = 0; index < names.count; index++) {
            UIView *item = [[NSClassFromString(names[index]) alloc] initWithFrame:CGRectMake(0, index * 74, 46, 62)];
            [self addSubview:item]; [items addObject:item];
        }
        self.items = items;
    }
    return self;
}
- (void)layoutSubviews {
    HGRightPasses++; [super layoutSubviews];
    for (NSUInteger index = 0; index < self.items.count; index++) self.items[index].frame = CGRectMake(0, index * 74, 46, 62);
}
@end

@interface SSTabBarController : UIViewController
@property(nonatomic, strong) SSTabBar *bar;
@property(nonatomic, strong) CYLTabBar *nativeBar;
@property(nonatomic, strong) SSVideoSeriesFeedViewController *feed;
@property(nonatomic, strong) FQVShortVideoListViewController *list;
@property(nonatomic, strong) FQVCollectionView *collection;
@property(nonatomic, strong) SSShortVideoRightInteractionView *right;
@property(nonatomic) NSUInteger taps;
@end
@implementation SSTabBarController
- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    CGSize size = self.view.bounds.size;
    self.feed.view.frame = self.view.bounds; self.list.view.frame = self.feed.view.bounds;
    self.collection.frame = CGRectMake(0, 0, size.width, size.height - 90);
    self.bar.frame = CGRectMake(0, size.height - 84, size.width, 84);
    self.nativeBar.frame = self.bar.frame;
    self.right.frame = CGRectMake(size.width - 56, size.height - 410, 46, 284);
}
- (void)tapped:(id)sender { self.taps++; }
@end

@interface FQVShortVideoBaseInsertView : UIView @end
@implementation FQVShortVideoBaseInsertView @end
@interface SSShortVideoDistributionContentView : UIView @end
@implementation SSShortVideoDistributionContentView @end
@interface SSShortVideoBottomDistributionView : UIView @end
@implementation SSShortVideoBottomDistributionView @end
static UIView *HGFixtureBottom, *HGFixtureBottomParent;
static UIImageView *HGFixtureBottomImage, *HGFixtureIcon;
static UIVisualEffectView *HGFixtureBottomBlur;
static UILabel *HGFixtureBottomLabel;
@interface HGRegressionApp : UIResponder <UIApplicationDelegate, UICollectionViewDataSource>
@property(nonatomic, strong) UIWindow *window;
@property(nonatomic, strong) SSTabBarController *fixture;
@property(nonatomic) NSUInteger phase;
@end
@implementation HGRegressionApp
- (NSInteger)collectionView:(UICollectionView *)view numberOfItemsInSection:(NSInteger)section { return 3; }
- (UICollectionViewCell *)collectionView:(UICollectionView *)view cellForItemAtIndexPath:(NSIndexPath *)path {
    return [view dequeueReusableCellWithReuseIdentifier:@"fixture" forIndexPath:path];
}
- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)options {
    self.window = [[UIWindow alloc] initWithFrame:UIScreen.mainScreen.bounds];
    SSRootViewController *root = [SSRootViewController new];
    self.window.rootViewController = root;
    SSTabBarController *fixture = [SSTabBarController new]; self.fixture = fixture;
    [root addChildViewController:fixture]; fixture.view.frame = root.view.bounds;
    fixture.view.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [root.view addSubview:fixture.view]; [fixture didMoveToParentViewController:root];
    fixture.feed = [SSVideoSeriesFeedViewController new];
    [fixture addChildViewController:fixture.feed]; [fixture.view addSubview:fixture.feed.view];
    [fixture.feed didMoveToParentViewController:fixture];
    fixture.list = [FQVShortVideoListViewController new];
    [fixture.feed addChildViewController:fixture.list]; [fixture.feed.view addSubview:fixture.list.view];
    [fixture.list didMoveToParentViewController:fixture.feed];
    fixture.collection = [[FQVCollectionView alloc] initWithFrame:CGRectZero collectionViewLayout:[HGFixtureLayout new]];
    fixture.collection.dataSource = self; fixture.collection.pagingEnabled = YES;
    [fixture.collection registerClass:FQVShortVideoCell.class forCellWithReuseIdentifier:@"fixture"];
    [fixture.list.view addSubview:fixture.collection];
    fixture.right = [[SSShortVideoRightInteractionView alloc] initWithFrame:CGRectMake(346, 436, 46, 284)];
    [fixture.feed.view addSubview:fixture.right];
    fixture.nativeBar = [CYLTabBar new]; fixture.nativeBar.alpha = 0;
    [fixture.view addSubview:fixture.nativeBar];
    fixture.bar = [[SSTabBar alloc] initWithFrame:CGRectMake(0, 790, 402, 84)];
    [fixture.view addSubview:fixture.bar];
    for (SSTabBarTextButton *button in fixture.bar.buttons) [button addTarget:fixture action:@selector(tapped:) forControlEvents:UIControlEventTouchUpInside];
    fixture.view.backgroundColor = UIColor.grayColor; fixture.list.view.backgroundColor = UIColor.grayColor;
    HGFixtureBottomParent = [[FQVShortVideoBaseInsertView alloc] initWithFrame:CGRectMake(0, 740, 402, 44)];
    HGFixtureBottomParent.backgroundColor = UIColor.grayColor;
    [fixture.list.view addSubview:HGFixtureBottomParent];
    HGFixtureBottom = [[SSShortVideoBottomDistributionView alloc] initWithFrame:HGFixtureBottomParent.bounds];
    HGFixtureBottom.backgroundColor = UIColor.grayColor; [HGFixtureBottomParent addSubview:HGFixtureBottom];
    UIView *content = [[SSShortVideoDistributionContentView alloc] initWithFrame:HGFixtureBottom.bounds];
    content.backgroundColor = UIColor.grayColor; [HGFixtureBottom addSubview:content];
    UIView *nested = [[UIView alloc] initWithFrame:content.bounds]; [content addSubview:nested];
    HGFixtureBottomImage = [[UIImageView alloc] initWithFrame:nested.bounds]; [nested addSubview:HGFixtureBottomImage];
    HGFixtureBottomBlur = [[UIVisualEffectView alloc] initWithEffect:[UIBlurEffect effectWithStyle:UIBlurEffectStyleDark]];
    HGFixtureBottomBlur.frame = nested.bounds; [nested addSubview:HGFixtureBottomBlur];
    HGFixtureIcon = [[UIImageView alloc] initWithFrame:CGRectMake(16, 12, 20, 20)]; [content addSubview:HGFixtureIcon];
    HGFixtureBottomLabel = [[UILabel alloc] initWithFrame:CGRectMake(38, 12, 200, 20)]; HGFixtureBottomLabel.text = @"观看完整短剧"; [content addSubview:HGFixtureBottomLabel];
    HGWriteProgress(-1);
    [self.window makeKeyAndVisible];
    [NSUserDefaults.standardUserDefaults setObject:@"SSTabBarTextButton layoutSubviews：历史测试记录" forKey:[HGPreferencePrefix stringByAppendingString:@"safety.lastReason"]];
    HGResetPreferences();
    [self performSelector:@selector(runPhase) withObject:nil afterDelay:0.6];
    return YES;
}
- (void)checkTabHeight:(CGFloat)height {
    SSTabBar *bar = self.fixture.bar;
    HGCheck(closeTo(bar.bounds.size.height, height), @"Configured tab height not applied");
    HGCheck(bar.oldBlur.hidden && bar.oldImage.hidden, @"Old background visible");
    HGCheck(closeTo(bar.row.bounds.size.width, 402), @"Plugin changed native row bounds");
    for (NSUInteger index = 0; index < 3; index++) {
        SSTabBarTextButton *button = bar.buttons[index];
        HGRect slot = HGTabButtonRect(bar.bounds.size.width, height, index, 3);
        HGCheck(closeTo(button.frame.origin.x, index * 135.3333) && closeTo(button.bounds.size.width, 131.3333), @"Plugin changed native button frame");
        HGCheck(rectClose(button.caption.frame, CGRectMake(49.6667, 13.6667, 32, 22.6667)), @"Plugin changed constrained caption frame");
        CATransform3D t = button.layer.sublayerTransform;
        CGPoint visual = [bar convertPoint:CGPointMake(button.caption.center.x + t.m41, button.caption.center.y + t.m42) fromView:button];
        HGCheck(closeTo(visual.x, slot.x + slot.width / 2) && closeTo(visual.y, height / 2), @"Tab pixels not centered");
        for (NSUInteger edge = 0; edge < 3; edge++) {
            CGFloat x = edge == 0 ? slot.x + 1 : edge == 1 ? slot.x + slot.width / 2 : slot.x + slot.width - 1;
            CGPoint p = CGPointMake(x, height / 2);
            HGCheck([bar hitTest:p withEvent:nil] == button, @"Visual tab slot routed to wrong native button");
            HGCheck([button pointInside:[button convertPoint:p fromView:bar] withEvent:nil], @"Native tracking rejected mapped touch");
        }
    }
    HGCheck(HGEnabled() && !HGSafetyPaused(), @"Tab layout triggered protection before deliberate stress");
    HGCheck(HGButtonPasses < 120, @"Tab constraint layouts did not converge");
}
- (UITableViewController *)makeSettings {
    UITableViewController *settings = [NSClassFromString(@"HGSettingsController") alloc];
    return [settings initWithStyle:UITableViewStyleInsetGrouped];
}
- (void)checkSettingsState:(NSString *)expected {
    UITableViewController *settings = [self makeSettings];
    UITableViewCell *status = [settings tableView:settings.tableView cellForRowAtIndexPath:[NSIndexPath indexPathForRow:1 inSection:0]];
    HGCheck([status.detailTextLabel.text isEqualToString:expected], @"Historical reason confused current settings state");
}
- (void)checkSliderMargins {
    UITableViewController *settings = [self makeSettings];
    UITableViewCell *cell = [settings tableView:settings.tableView cellForRowAtIndexPath:[NSIndexPath indexPathForRow:5 inSection:1]];
    for (NSNumber *width in @[@280, @370, @500]) {
        cell.frame = CGRectMake(0, 0, width.doubleValue, 84);
        [cell setNeedsLayout]; [cell layoutIfNeeded]; [cell.contentView layoutIfNeeded];
        UISlider *slider = (id)[cell.contentView viewWithTag:105];
        HGCheck(slider != nil, @"Slider cell not configured");
        HGCheck(CGRectGetMinX(slider.frame) >= 15.7 && CGRectGetMaxX(slider.frame) <= CGRectGetWidth(cell.contentView.bounds) - 15.7, @"Slider overflowed card");
    }
}
- (void)finishAfterRecovery {
    @try {
        [self checkTabHeight:54];
        [self checkSettingsState:@"正在运行"];
        HGCheck(HGEnabled() && !HGSafetyPaused(), @"Manual retry retriggered tab feedback");
        HGClearSafetyRecord();
        HGCheck(!HGSafetyReason().length && HGEnabled(), @"Clearing historical record changed active state");
        HGFinish(nil);
    } @catch (NSException *exception) { HGFinish(exception.reason); }
}
- (void)runPhase {
    HGWriteProgress(self.phase);
    @try {
        NSArray *scales = @[@0.55, @0.80, @1.0, @0.55, @0.80];
        if (self.phase == 0) {
            for (UIView *item in self.fixture.right.items) HGCheck(closeTo(item.layer.sublayerTransform.m11, 0.8), @"Cold launch scaled only one interaction");
            UIView *header = [[SSVideoSeriesFeedHeaderView alloc] initWithFrame:CGRectMake(0, 62, 300, 44)];
            [self.fixture.feed.view addSubview:header];
            UILabel *title = [UILabel new]; [header addSubview:title];
            for (NSUInteger repeat = 0; repeat < 10; repeat++) {
                title.font = [UIFont systemFontOfSize:20];
                HGCheck(closeTo(title.font.pointSize, 17), @"Host top font reset defeated scaling");
            }
            HGWritePreference(@"top.enabled", @NO); title.font = [UIFont systemFontOfSize:20];
            HGCheck(closeTo(title.font.pointSize, 20), @"Top font failed to restore");
            HGWritePreference(@"top.enabled", @YES); [header layoutSubviews];
            HGCheck(closeTo(title.font.pointSize, 17), @"Top font retry accumulated scaling");
            NSAttributedString *rich = [[NSAttributedString alloc] initWithString:@"推荐" attributes:@{NSFontAttributeName:[UIFont boldSystemFontOfSize:20], NSForegroundColorAttributeName:UIColor.whiteColor}];
            for (NSUInteger repeat = 0; repeat < 5; repeat++) {
                title.attributedText = rich;
                HGCheck(closeTo([[title.attributedText attribute:NSFontAttributeName atIndex:0 effectiveRange:nil] pointSize], 17), @"Attributed top font reset defeated scaling");
                [header layoutSubviews];
                HGCheck(closeTo([[title.attributedText attribute:NSFontAttributeName atIndex:0 effectiveRange:nil] pointSize], 17), @"Attributed top font shrank cumulatively");
            }
            HGWritePreference(@"top.enabled", @NO); [header layoutSubviews];
            HGCheck(closeTo([[title.attributedText attribute:NSFontAttributeName atIndex:0 effectiveRange:nil] pointSize], 20), @"Attributed font failed to restore");
            HGWritePreference(@"top.enabled", @YES);
            [header removeFromSuperview];
            FQVShortVideoListViewController *detail = [FQVShortVideoListViewController new];
            [self.window.rootViewController addChildViewController:detail];
            [self.window.rootViewController.view addSubview:detail.view];
            SSShortVideoRightInteractionView *detailRight = [[SSShortVideoRightInteractionView alloc] initWithFrame:CGRectMake(346, 481, 46, 284)];
            [detail.view addSubview:detailRight]; [detailRight layoutSubviews];
            for (UIView *item in detailRight.items) HGCheck(closeTo(item.layer.sublayerTransform.m11, 0.8), @"Standalone all-episodes scaling missing");
            HGWritePreference(@"right.gap", @0); [detailRight layoutSubviews];
            HGCheck(closeTo(HGVisualY(detailRight.items[1]) - HGVisualY(detailRight.items[0]), 49.6), @"Right gap did not compact scaled items");
            HGWritePreference(@"right.gap", @24); [detailRight layoutSubviews];
            HGCheck(closeTo(HGVisualY(detailRight.items[1]) - HGVisualY(detailRight.items[0]), 73.6), @"Right gap setting ineffective");
            HGWritePreference(@"right.gap", @6);
            [detail.view removeFromSuperview]; [detail removeFromParentViewController];
            HGCheck(HGFixtureBottomImage.hidden && HGFixtureBottomBlur.hidden, @"Nested bottom image or material remained visible");
            HGCheck([HGFixtureBottom.backgroundColor isEqual:UIColor.clearColor] && [HGFixtureBottomParent.backgroundColor isEqual:UIColor.clearColor], @"Bottom parent paint remained gray");
            HGCheck([self.fixture.view.backgroundColor isEqual:UIColor.clearColor] && [self.fixture.list.view.backgroundColor isEqual:UIColor.clearColor], @"Controller canvas below viewport remained gray");
            HGCheck(!HGFixtureIcon.hidden && !HGFixtureBottomLabel.hidden, @"Bottom cleanup removed navigation content");
            [self checkTabHeight:54];
            [self checkSettingsState:@"正在运行"]; [self checkSliderMargins];
            HGCheck(method_getImplementation(class_getInstanceMethod(SSTabBarTextButton.class, @selector(setFrame:))) == HGButtonFrameBeforeLoad, @"Native tab frame method was hooked");
            CGFloat height = self.fixture.collection.superview.bounds.size.height - 90;
            HGCheck(closeTo(self.fixture.collection.bounds.size.height, height), @"Hotfix changed the native feed viewport");
            UICollectionViewLayout *layout = self.fixture.collection.collectionViewLayout;
            CGRect page = [layout layoutAttributesForItemAtIndexPath:[NSIndexPath indexPathForItem:1 inSection:0]].frame;
            HGCheck(closeTo(page.origin.y, 784) && closeTo(page.size.height, 784), @"Hotfix changed native page attributes");
            HGCheck(closeTo(layout.collectionViewContentSize.height, 784 * 3), @"Hotfix changed native content size");
            for (SSTabBarTextButton *button in self.fixture.bar.buttons) [button sendActionsForControlEvents:UIControlEventTouchUpInside];
            HGCheck(self.fixture.taps == 3, @"Original tab actions lost");
            HGCheck(method_getImplementation(class_getInstanceMethod(FQVCollectionView.class, @selector(setFrame:))) == HGFeedFrameBeforeLoad, @"Feed frame method was hooked");
            HGCheck(method_getImplementation(class_getInstanceMethod(FQVPlayer.class, @selector(setFrame:))) == HGPlayerFrameBeforeLoad, @"Player frame method was hooked");
            HGCheck(method_getImplementation(class_getInstanceMethod(HGFixtureLayout.class, @selector(layoutAttributesForItemAtIndexPath:))) == HGItemBeforeLoad, @"Native item attributes were hooked");
            HGCheck(method_getImplementation(class_getInstanceMethod(HGFixtureLayout.class, @selector(collectionViewContentSize))) == HGSizeBeforeLoad, @"Native content size was hooked");
            HGWritePreference(@"video.extend", @YES);
            HGCheck(!HGBool(@"video.extend"), @"Saved fullscreen setting bypassed hotfix isolation");
            HGWritePreference(@"right.scale", scales[0]);
        } else if (self.phase <= scales.count) {
            double expected = [scales[self.phase - 1] doubleValue];
            NSUInteger itemIndex = 0;
            for (UIView *item in self.fixture.right.items) {
                HGCheck(closeTo(item.frame.origin.y, itemIndex * 74), @"Plugin changed native interaction frame");
                CGFloat center = 284 - (4 * 62 * expected + 3 * HGNumber(@"right.gap")) + 31 * expected + itemIndex * (62 * expected + HGNumber(@"right.gap"));
                HGCheck(closeTo(HGVisualY(item), center), @"Right visual spacing was overwritten by host layout");
                CGPoint touch = CGPointMake(23, center);
                UIView *hit = [self.fixture.right hitTest:touch withEvent:nil];
                HGCheck(hit == item || [hit isDescendantOfView:item], @"Compact visual control touch mapped to wrong item");
                itemIndex++;
                HGCheck(closeTo(item.layer.sublayerTransform.m11, expected), @"Right visual scaling not applied or accumulated");
                HGCheck(CGAffineTransformIsIdentity(item.transform), @"Scaling changed the hit-test view transform");
                HGCheck(closeTo(item.bounds.size.width, 46) && closeTo(item.bounds.size.height, 62), @"Scaling resized native hit bounds");
            }
            HGCheck(HGRightPasses < 150 && HGBarPasses < 150, @"Layouts failed to converge");
            if (self.phase < scales.count) HGWritePreference(@"right.scale", scales[self.phase]);
            else HGWritePreference(@"tab.height", @44);
        } else if (self.phase == 6) {
            [self checkTabHeight:44]; HGWritePreference(@"tab.height", @80);
        } else if (self.phase == 7) {
            [self checkTabHeight:80]; HGWritePreference(@"tab.height", @54);
        } else if (self.phase == 8) {
            [self checkTabHeight:54]; HGWritePreference(@"right.comment", @NO);
        } else if (self.phase == 9) {
            HGCheck(self.fixture.right.items[1].hidden, @"Right visibility switch did not hide comment");
            HGCheck(closeTo(HGVisualY(self.fixture.right.items[0]), 284 - (3 * 62 * HGNumber(@"right.scale") + 2 * HGNumber(@"right.gap")) + 31 * HGNumber(@"right.scale")), @"Visible right items did not compact");
            HGWritePreference(@"enabled", @NO);
        } else {
            HGCheck(!self.fixture.bar.oldBlur.hidden && !self.fixture.bar.oldImage.hidden, @"Tab backgrounds did not restore");
            HGCheck(closeTo(self.fixture.bar.bounds.size.height, 84), @"Original tab frame did not restore");
            HGCheck(closeTo(self.fixture.collection.bounds.size.height, self.fixture.list.view.bounds.size.height - 90), @"Feed viewport did not restore");
            for (UIView *item in self.fixture.right.items) HGCheck(CATransform3DIsIdentity(item.layer.sublayerTransform), @"Right visual scale did not restore");
            HGCheck(!HGFixtureBottomImage.hidden && !HGFixtureBottomBlur.hidden, @"Bottom materials failed to restore when disabled");
            HGCheck([self.fixture.list.view.backgroundColor isEqual:UIColor.grayColor], @"Playback canvas did not restore");
            HGCheck([HGFixtureBottomParent.backgroundColor isEqual:UIColor.grayColor], @"Bottom parent color failed to restore");
            [self checkSettingsState:@"已关闭"];
            HGSteadyRightPasses = HGRightPasses; HGSteadyButtonPasses = HGButtonPasses;
            HGWritePreference(@"enabled", @YES);
            for (NSUInteger n = 0; n < 160; n++) [self.fixture.right layoutSubviews];
            HGCheck(!HGEnabled(), @"Layout burst failed to disable enhancements");
            HGCheck(HGSafetyReason().length > 0, @"Circuit breaker did not record its reason");
            HGDidTripSafety = HGSafetyPaused();
            [self checkSettingsState:@"已暂停（布局保护）"];
            HGWritePreference(@"enabled", @YES);
            HGCheck(HGEnabled() && !HGSafetyPaused(), @"Explicit retry did not reset pause");
            HGCheck(HGSafetyReason().length > 0, @"Explicit retry deleted historical record");
            [self performSelector:@selector(finishAfterRecovery) withObject:nil afterDelay:0.3]; return;
        }
        if (self.phase < 9) dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.08 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            // Host resets every item after normal layout callbacks, including the first cold appearance.
            for (UIView *item in self.fixture.right.items) item.layer.sublayerTransform = CATransform3DIdentity;
        });
        self.phase++;
        [self performSelector:@selector(runPhase) withObject:nil afterDelay:0.18];
    } @catch (NSException *exception) { HGFinish(exception.reason); }
}
@end
__attribute__((constructor))
static void HGRecordNativeMethods(void) {
    HGButtonFrameBeforeLoad = method_getImplementation(class_getInstanceMethod(SSTabBarTextButton.class, @selector(setFrame:)));
    HGFeedFrameBeforeLoad = method_getImplementation(class_getInstanceMethod(FQVCollectionView.class, @selector(setFrame:)));
    HGPlayerFrameBeforeLoad = method_getImplementation(class_getInstanceMethod(FQVPlayer.class, @selector(setFrame:)));
    HGItemBeforeLoad = method_getImplementation(class_getInstanceMethod(HGFixtureLayout.class, @selector(layoutAttributesForItemAtIndexPath:)));
    HGSizeBeforeLoad = method_getImplementation(class_getInstanceMethod(HGFixtureLayout.class, @selector(collectionViewContentSize)));
}
int main(int argc, char *argv[]) {
    @autoreleasepool { return UIApplicationMain(argc, argv, nil, NSStringFromClass(HGRegressionApp.class)); }
}




