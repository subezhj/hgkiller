#import <UIKit/UIKit.h>
#import "HGCore.h"
#import "HGGeometry.h"
#import <math.h>

static NSUInteger HGBarPasses, HGRightPasses, HGChecks, HGSteadyRightPasses, HGButtonPasses, HGSteadyButtonPasses;
static BOOL HGDidTripSafety;
static UIView *HGProjectedPlayer, *HGProjectedControls;
static UILabel *HGProjectedTitle;
static UIView *HGReclaimedEntry;
static BOOL HGHostCachesCellHeight;
static NSUInteger HGNativeCellRejections;
static IMP HGFeedFrameBeforeLoad, HGPlayerFrameBeforeLoad, HGItemBeforeLoad, HGSizeBeforeLoad, HGButtonFrameBeforeLoad, HGTabFrameOriginal, HGTabLayoutOriginal;
static void HGFinish(NSString *error) {
    NSString *path = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES).firstObject
                      stringByAppendingPathComponent:@"hg-results.json"];
    NSDictionary *result = @{@"success": @(!error), @"checks": @(HGChecks),
                             @"tabLayoutPasses": @(HGBarPasses), @"rightLayoutPasses": @(HGRightPasses), @"nativeCellRejections": @(HGNativeCellRejections),
                             @"error": error ?: @"", @"steadyRightLayoutPasses": @(HGSteadyRightPasses), @"safetyTripped": @(HGDidTripSafety), @"recoveredEnabled": @(HGEnabled()), @"currentSafetyPaused": @(HGSafetyPaused()), @"buttonLayoutPasses": @(HGButtonPasses), @"steadyButtonLayoutPasses": @(HGSteadyButtonPasses)};
    [[NSJSONSerialization dataWithJSONObject:result options:NSJSONWritingPrettyPrinted error:nil] writeToFile:path atomically:YES];
}
static void HGCheck(BOOL condition, NSString *message) {
    HGChecks++;
    if (!condition) @throw [NSException exceptionWithName:@"HGRegressionFailure" reason:message userInfo:nil];
}
static BOOL closeTo(CGFloat a, CGFloat b) { return fabs(a - b) < 0.3; }

static BOOL HGUnitClose(CGFloat a, CGFloat b) { return fabs(a - b) < 0.001; }
static CGFloat HGVisualY(UIView *view) { return [view.superview convertPoint:CGPointMake(CGRectGetMidX(view.bounds), CGRectGetMidY(view.bounds)) fromView:view].y; }
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
@interface SSSettingViewController : UITableViewController @end
@implementation SSSettingViewController @end
@interface SSVideoSeriesFeedViewController : UIViewController @end
@implementation SSVideoSeriesFeedViewController @end
@interface FQVShortVideoListViewController : UIViewController @end
@implementation FQVShortVideoListViewController @end
@interface SSVideoSeriesFeedHeaderView : UIView @end
@implementation SSVideoSeriesFeedHeaderView @end
@interface SSShortVideoOutterSeriesLeftContainerView : UIView @end
@implementation SSShortVideoOutterSeriesLeftContainerView @end
@interface SSShortVideoSingleSeriesInfoLeftContainerView : UIView @end
@implementation SSShortVideoSingleSeriesInfoLeftContainerView @end
@interface FQVShortVideoGradientLayerView : UIView @end
@implementation FQVShortVideoGradientLayerView @end
@interface YYLabel : UIView
@property(nonatomic, strong) UIFont *font;
@end
@implementation YYLabel @end
@interface FQVCollectionView : UICollectionView @end
@implementation FQVCollectionView @end
@interface FQVShortVideoCell : UICollectionViewCell @end
@implementation FQVShortVideoCell
- (void)layoutSubviews {
    [super layoutSubviews];
    if (!HGHostCachesCellHeight) return;
    // Model a host whose video model retains its captured 784 pt page geometry.
    BOOL rejected = !closeTo(self.contentView.bounds.size.height, 784);
    if (rejected) HGNativeCellRejections++;
    if (rejected && HGNativeCellRejections < 5) [self setNeedsLayout];
    self.contentView.frame = CGRectMake(0, 0, self.bounds.size.width, 784);
    for (UIView *child in self.contentView.subviews) {
        if (HGIsClass(child, @"FQVPlayer") || HGIsClass(child, @"FQVShortVideoVPlayerOutterMultiSeriesControlView"))
            child.frame = CGRectMake(0, 0, self.bounds.size.width, 784);
    }
}
@end
@interface FQVShortVideoVPlayerOutterMultiSeriesControlView : UIView @end
@implementation FQVShortVideoVPlayerOutterMultiSeriesControlView @end
@interface FQVPlayer : UIView @end
@implementation FQVPlayer @end
@interface TTPlayerView : UIView @end
@implementation TTPlayerView @end
static NSUInteger HGLandscapeCalls, HGLandscapeWrongCalls, HGLandscapeExitCalls;
@interface SSFixtureLandscapeTarget : NSObject
@property(nonatomic) BOOL offscreen;
- (void)enterFullScreen:(id)sender;
- (void)exitFullScreen:(id)sender;
- (void)onButtonTap:(id)sender;
@end
@implementation SSFixtureLandscapeTarget
- (void)enterFullScreen:(id)sender { if (self.offscreen) HGLandscapeWrongCalls++; else HGLandscapeCalls++; }
- (void)exitFullScreen:(id)sender { HGLandscapeExitCalls++; }
- (void)onButtonTap:(id)sender { [self enterFullScreen:sender]; }
@end

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
- (CGPoint)targetContentOffsetForProposedContentOffset:(CGPoint)offset withScrollingVelocity:(CGPoint)velocity {
    offset.y = round(offset.y / self.collectionView.frame.size.height) * self.collectionView.frame.size.height;
    return offset;
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
        self.label.text = @"首页"; self.caption.userInteractionEnabled = NO;
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

static NSUInteger HGRightActionCount;
@interface HGFixtureRightItem : UIView
@property(nonatomic, strong) UIButton *action;
@end
@implementation HGFixtureRightItem
- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        UIView *icon = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 46, 46)];
        icon.backgroundColor = UIColor.whiteColor;
        self.action = [UIButton buttonWithType:UIButtonTypeCustom]; self.action.frame = self.bounds;
        self.action.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        [self.action addTarget:self action:@selector(onTap:) forControlEvents:UIControlEventTouchUpInside];
        UILabel *text = [[UILabel alloc] initWithFrame:CGRectMake(0, 46, 46, 16)];
        text.text = @"收藏"; [self addSubview:icon]; [self addSubview:text]; [self addSubview:self.action];
    }
    return self;
}
- (void)onTap:(id)sender { HGRightActionCount++; }
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
    for (NSUInteger index = 0; index < self.items.count; index++) {
        CGRect native = CGRectMake(0, index * 74, 46, 62);
        // Host insists on its own item frames, and repeats layout if the plugin presents transformed geometry.
        if (!rectClose(self.items[index].frame, native)) [self setNeedsLayout];
        self.items[index].frame = native;
    }
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
static UILabel *HGFixtureBottomLabel, *HGFixtureDramaTitle;
static UIView *HGFixtureDramaContainer;
@interface HGRegressionApp : UIResponder <UIApplicationDelegate, UICollectionViewDataSource>
@property(nonatomic, strong) UIWindow *window;
@property(nonatomic, strong) SSTabBarController *fixture;
@property(nonatomic) NSUInteger phase;
@end
@implementation HGRegressionApp
- (NSInteger)collectionView:(UICollectionView *)view numberOfItemsInSection:(NSInteger)section { return 3; }
- (UICollectionViewCell *)collectionView:(UICollectionView *)view cellForItemAtIndexPath:(NSIndexPath *)path {
    UICollectionViewCell *cell = [view dequeueReusableCellWithReuseIdentifier:@"fixture" forIndexPath:path];
    if (!cell.contentView.subviews.count) {
        UIView *player = [[FQVPlayer alloc] initWithFrame:CGRectMake(0, 0, view.bounds.size.width, 784)];
        player.autoresizingMask = UIViewAutoresizingFlexibleWidth; [cell.contentView addSubview:player];
        UIView *controls = [[FQVShortVideoVPlayerOutterMultiSeriesControlView alloc] initWithFrame:player.frame];
        controls.autoresizingMask = UIViewAutoresizingFlexibleWidth; [cell.contentView addSubview:controls];
        UILabel *title = [[UILabel alloc] initWithFrame:CGRectMake(16, 645, 240, 22)];
        title.text = @"别叫姐姐"; [controls addSubview:title];
        UIView *entry = [[FQVShortVideoBaseInsertView alloc] initWithFrame:CGRectMake(0, 740, view.bounds.size.width, 44)];
        [controls addSubview:entry];
        if (path.item == 0) { HGProjectedPlayer = player; HGProjectedControls = controls; HGProjectedTitle = title; HGReclaimedEntry = entry; }
    }
    return cell;
}
- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)options {
    HGResetPreferences(); [NSUserDefaults.standardUserDefaults setDouble:66 forKey:[HGPreferencePrefix stringByAppendingString:@"tab.backgroundHeight"]];
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
    HGFixtureDramaContainer = [[SSShortVideoOutterSeriesLeftContainerView alloc] initWithFrame:CGRectMake(16, 645, 282, 80)];
    [fixture.list.view addSubview:HGFixtureDramaContainer];
    HGFixtureDramaTitle = [[UILabel alloc] initWithFrame:CGRectMake(0, 30, 240, 22)];
    HGFixtureDramaTitle.text = @"别叫姐姐"; HGFixtureDramaTitle.font = [UIFont systemFontOfSize:18];
    [HGFixtureDramaContainer addSubview:HGFixtureDramaTitle];
    HGWriteProgress(-1);
    [self.window makeKeyAndVisible];
    [NSUserDefaults.standardUserDefaults setObject:@"SSTabBarTextButton layoutSubviews：历史测试记录" forKey:[HGPreferencePrefix stringByAppendingString:@"safety.lastReason"]];
    [self performSelector:@selector(runPhase) withObject:nil afterDelay:0.6];
    return YES;
}
- (void)checkTabHeight:(CGFloat)height {
    SSTabBar *bar = self.fixture.bar;
    [self.fixture.collection layoutSubviews];
    HGCheck(rectClose(bar.frame, CGRectMake(0, self.window.bounds.size.height - 84, self.window.bounds.size.width, 84)), @"Legacy height setting still changes native tab frame");
    HGCheck(!bar.oldBlur.hidden && !bar.oldImage.hidden, @"Native background changed");
    HGCheck(!HGBool(@"tab.layout.enabled"), @"Allocation must be disabled during native baseline checks");
    HGCheck(!HGBool(@"tab.appearance.enabled"), @"Appearance should be disabled during native baseline checks");
    for (CALayer *layer in bar.layer.superlayer.sublayers) HGCheck(![layer.name isEqualToString:@"HGK.nativeTabUnderlay"], @"Black tab underlay still installed");
    HGCheck(bar.subviews.count == 3, @"Plugin inserted a floating blur background");
    HGCheck(closeTo(bar.row.bounds.size.width, 402), @"Plugin changed native row bounds");
    for (NSUInteger index = 0; index < 3; index++) {
        SSTabBarTextButton *button = bar.buttons[index];
        HGRect slot = { index * 135.3333, 0, 131.3333, 49.6667 };
        HGCheck(closeTo(button.frame.origin.x, index * 135.3333) && closeTo(button.bounds.size.width, 131.3333), @"Plugin changed native button frame");
        HGCheck(rectClose(button.caption.frame, CGRectMake(49.6667, 13.6667, 32, 22.6667)), @"Plugin changed constrained caption frame");
        CATransform3D t = button.layer.sublayerTransform;
        CGPoint visual = [bar convertPoint:CGPointMake(button.caption.center.x + t.m41, button.caption.center.y + t.m42) fromView:button];
        HGCheck(closeTo(visual.x, slot.x + 65.6667) && closeTo(visual.y, button.caption.center.y) && CATransform3DIsIdentity(t), @"Tab pixels not centered");
        for (NSUInteger edge = 0; edge < 3; edge++) {
            CGFloat x = edge == 0 ? slot.x + 1 : edge == 1 ? slot.x + slot.width / 2 : slot.x + slot.width - 1;
            CGPoint p = CGPointMake(x, slot.height / 2);
            HGCheck([bar hitTest:p withEvent:nil] == button, @"Visual tab slot routed to wrong native button");
            HGCheck([button pointInside:[button convertPoint:p fromView:bar] withEvent:nil], @"Native tracking rejected mapped touch");
        }
    }
    HGCheck(rectClose(HGFixtureDramaContainer.frame, CGRectMake(16, 645, 282, 80)), @"Drama caption container moved with tab height");
    HGCheck(rectClose(HGFixtureDramaTitle.frame, CGRectMake(0, 30, 240, 22)) && closeTo(HGFixtureDramaTitle.font.pointSize, 18), @"Drama title position or font was changed");
    HGCheck(rectClose(HGFixtureBottomParent.frame, CGRectMake(0, 740, 402, 44)), @"Native episode entry moved with tab height");
    HGCheck(closeTo(self.fixture.collection.bounds.size.height, self.fixture.list.view.bounds.size.height - 90), @"Tab height changed video viewport");
    HGCheck(HGProjectedPlayer && HGProjectedTitle, @"Projection fixture missing");
    CGPoint videoBottom = [HGProjectedPlayer.layer convertPoint:CGPointMake(HGProjectedPlayer.bounds.size.width / 2, 784) toLayer:self.window.layer];
    HGCheck(closeTo(videoBottom.y, 784), @"Native video edge changed after projection rollback");
    HGCheck(CATransform3DIsIdentity(self.fixture.collection.layer.sublayerTransform) && self.fixture.collection.layer.mask == nil, @"List-wide video projection remains installed");
    CGPoint titleCenter = [HGProjectedTitle.layer convertPoint:CGPointMake(120, 11) toLayer:self.window.layer];
    HGCheck(closeTo(titleCenter.x, 136) && closeTo(titleCenter.y, 656), @"Video projection moved drama text pixels");
    HGCheck(closeTo(HGProjectedPlayer.bounds.size.height, 784), @"Player geometry changed during projection");
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
    [settings setValue:@"home" forKey:@"settingsPage"];
    UITableViewCell *cell = [settings tableView:settings.tableView cellForRowAtIndexPath:[NSIndexPath indexPathForRow:5 inSection:0]];
    for (NSNumber *width in @[@280, @370, @500]) {
        cell.frame = CGRectMake(0, 0, width.doubleValue, 84);
        [cell setNeedsLayout]; [cell layoutIfNeeded]; [cell.contentView layoutIfNeeded];
        UISlider *slider = (id)[cell.contentView viewWithTag:5];
        HGCheck(slider != nil, @"Slider cell not configured");
        HGCheck(CGRectGetMinX(slider.frame) >= 15.7 && CGRectGetMaxX(slider.frame) <= CGRectGetWidth(cell.contentView.bounds) - 15.7, @"Slider overflowed card");
    }
}
- (void)finishAfterRecovery {
    @try {
        [self checkTabHeight:50];
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
            HGCheck(closeTo(self.fixture.bar.bounds.size.height, 84), @"Old cold-start height setting remained active");
            HGCheck(closeTo(CGRectGetMaxY(self.fixture.bar.frame), self.window.bounds.size.height), @"Cold launch needed navigation to align tab");
            HGResetPreferences(); [self.fixture.bar layoutSubviews];
            for (UIView *item in self.fixture.right.items) HGCheck(closeTo(item.transform.a, 0.8), @"Cold launch scaled only one interaction");
            YYLabel *description = [[YYLabel alloc] initWithFrame:CGRectMake(0, 60, 240, 20)]; description.font = [UIFont systemFontOfSize:16];
            [HGFixtureDramaContainer addSubview:description];
            HGWritePreference(@"caption.titleScale", @0.8); HGWritePreference(@"caption.descriptionScale", @0.75);
            [HGFixtureDramaContainer layoutSubviews];
            HGCheck(closeTo(HGFixtureDramaTitle.font.pointSize, 14.4), @"Drama title custom size ignored");
            HGCheck(closeTo(description.font.pointSize, 12), @"YYLabel description custom size ignored");
            for (NSUInteger n = 0; n < 8; n++) { HGFixtureDramaTitle.font = [UIFont systemFontOfSize:18]; description.font = [UIFont systemFontOfSize:16]; }
            HGCheck(closeTo(HGFixtureDramaTitle.font.pointSize, 14.4) && closeTo(description.font.pointSize, 12), @"Host reset defeated caption font customization");
            HGWritePreference(@"caption.enabled", @NO); [HGFixtureDramaContainer layoutSubviews];
            HGCheck(closeTo(HGFixtureDramaTitle.font.pointSize, 18) && closeTo(description.font.pointSize, 16), @"Caption font failed to restore");
            HGWritePreference(@"caption.titleScale", @1); HGWritePreference(@"caption.descriptionScale", @1); HGWritePreference(@"caption.enabled", @YES);
            [description removeFromSuperview];
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
            for (UIView *item in detailRight.items) HGCheck(closeTo(item.transform.a, 0.8), @"Standalone all-episodes scaling missing");
            HGWritePreference(@"right.gap", @0); [detailRight layoutSubviews];
            HGCheck(closeTo(HGVisualY(detailRight.items[1]) - HGVisualY(detailRight.items[0]), 49.6), @"Right gap did not compact scaled items");
            HGWritePreference(@"right.gap", @24); [detailRight layoutSubviews];
            HGCheck(closeTo(HGVisualY(detailRight.items[1]) - HGVisualY(detailRight.items[0]), 73.6), @"Right gap setting ineffective");
            HGWritePreference(@"right.gap", @6);
            UIView *avatar = [[SSShortVideoRightInteractionAvatarView alloc] initWithFrame:CGRectMake(0, 0, 46, 46)];
            for (UIView *child in avatar.subviews.copy) [child removeFromSuperview];
            UIView *badge = [[UIView alloc] initWithFrame:CGRectMake(3, 24, 40, 26)]; [avatar addSubview:badge];
            [detailRight addSubview:avatar]; detailRight.frame = CGRectMake(346, 423, 46, 342);
            for (NSUInteger cycle = 0; cycle < 6; cycle++) {
                // Collection/detail constraints bypass setFrame and write center/bounds directly.
                for (NSUInteger index = 0; index < detailRight.items.count; index++) {
                    UIView *item = detailRight.items[index]; item.bounds = CGRectMake(0, 0, 46, 62);
                    item.center = CGPointMake(index == 3 ? 46 : 23, 90 + index * 134 + cycle * 7);
                }
                avatar.center = CGPointMake(23, 70 + cycle * 10);
                [detailRight.items.lastObject setHidden:YES];
                [detailRight layoutSubviews];
                // Reset once more after layout to reproduce the captured late constraints update.
                for (NSUInteger index = 0; index < 3; index++) detailRight.items[index].center = CGPointMake(23, 90 + index * 134 + cycle * 7);
                for (UIView *item in detailRight.items) [item layoutSubviews]; [avatar layoutSubviews];
                CGFloat y = 342 - (50 * 0.8 + 3 * 62 * 0.8 + 3 * 6);
                HGCheck(closeTo(HGVisualY(avatar), y + 46 * 0.8 / 2), @"Avatar shifted after direct native center update");
                y += 50 * 0.8 + 6;
                for (NSUInteger index = 0; index < 3; index++) {
                    UIView *item = detailRight.items[index]; CGFloat center = y + 62 * 0.8 / 2;
                    HGCheck(closeTo(HGVisualY(item), center), @"Detail interaction translation accumulated");
                    HGCheck(CGRectGetMinY(item.frame) >= 0 && CGRectGetMaxY(item.frame) <= 342.1, @"Detail interaction escaped container");
                    CGPoint pixel = [detailRight convertPoint:CGPointMake(23, 31) fromView:item];
                    HGCheck(closeTo(pixel.x, 23), @"Detail interaction shifted horizontally");
                    UIView *hit = [detailRight hitTest:CGPointMake(23, center) withEvent:nil];
                    HGCheck(hit == item || [hit isDescendantOfView:item], @"Detail control click lost after center update");
                    y += 62 * 0.8 + 6;
                }
            }
            [avatar removeFromSuperview];
            HGWritePreference(@"profiles.enabled", @YES);
            HGCheck(HGUnitClose(HGNumber(@"detail.right.scale"), HGNumber(@"right.scale")), @"First independent profile did not copy current settings");
            HGWritePreference(@"detail.right.scale", @0.6); HGWritePreference(@"detail.right.gap", @2);
            [detailRight layoutSubviews]; [self.fixture.right layoutSubviews];
            HGCheck(HGUnitClose(detailRight.items.firstObject.transform.a, 0.6) && HGUnitClose(self.fixture.right.items.firstObject.transform.a, 0.8), @"Detail right scale leaked into home");
            UIView *detailCaption = [[SSShortVideoSingleSeriesInfoLeftContainerView alloc] initWithFrame:CGRectMake(16, 645, 282, 80)];
            [detail.view addSubview:detailCaption];
            UILabel *detailTitle = [[UILabel alloc] initWithFrame:CGRectMake(0, 30, 240, 22)]; [detailCaption addSubview:detailTitle];
            HGWritePreference(@"detail.caption.titleScale", @0.7); detailTitle.font = [UIFont systemFontOfSize:18];
            [detailCaption layoutSubviews];
            HGCheck(closeTo(detailTitle.font.pointSize, 12.6) && closeTo(HGFixtureDramaTitle.font.pointSize, 18), @"Detail caption scale did not stay independent");
            UIView *cleanHeader = [[SSVideoSeriesFeedHeaderView alloc] initWithFrame:CGRectMake(0, 62, 300, 44)]; [self.fixture.feed.view addSubview:cleanHeader];
            UITableViewController *viewingSettings = [self makeSettings];
            [viewingSettings setValue:@"home" forKey:@"settingsPage"];
            UISwitch *cleanSwitch = (id)[viewingSettings tableView:viewingSettings.tableView cellForRowAtIndexPath:[NSIndexPath indexPathForRow:0 inSection:3]].accessoryView;
            cleanSwitch.on = YES; [cleanSwitch sendActionsForControlEvents:UIControlEventValueChanged];
            HGApplyViewing(self.fixture.right); HGApplyViewing(HGFixtureDramaContainer); HGApplyViewing(cleanHeader); HGApplyViewing(detailRight); HGApplyViewing(HGFixtureBottom);
            HGCheck(self.fixture.right.hidden && HGFixtureDramaContainer.hidden && cleanHeader.hidden, @"Pure mode did not hide configured home overlays");
            HGCheck(!detailRight.hidden && !HGFixtureBottom.hidden, @"Home pure mode hid independent detail or default retained episode entry");
            HGCheck([self.fixture.right hitTest:CGPointMake(23, 100) withEvent:nil] == nil, @"Hidden pure-mode right controls still intercept video touches");
            for (NSUInteger n = 0; n < 5; n++) { cleanHeader.hidden = NO; HGApplyViewing(cleanHeader); }
            HGCheck(cleanHeader.hidden, @"Host show defeated pure mode");
            HGWritePreference(@"detail.clean.enabled", @YES); HGApplyViewing(detailRight); HGApplyViewing(detailCaption);
            HGCheck(detailRight.hidden && detailCaption.hidden, @"Independent detail pure mode did not apply");
            detailCaption.hidden = YES;
            HGWritePreference(@"detail.clean.enabled", @NO); HGApplyViewing(detailCaption); HGApplyViewing(detailRight);
            HGCheck(detailCaption.hidden && !detailRight.hidden, @"Pure mode failed to retain host hidden intent on restore");
            detailCaption.hidden = NO;
            cleanSwitch.on = NO; [cleanSwitch sendActionsForControlEvents:UIControlEventValueChanged];
            HGApplyViewing(self.fixture.right); HGApplyViewing(HGFixtureDramaContainer); HGApplyViewing(cleanHeader);
            HGCheck(!self.fixture.right.hidden && !HGFixtureDramaContainer.hidden && !cleanHeader.hidden, @"Turning off pure mode did not restore overlays");
            UIView *topShade = [[FQVShortVideoGradientLayerView alloc] initWithFrame:CGRectMake(0, 0, 402, 159)];
            UIView *bottomShade = [[FQVShortVideoGradientLayerView alloc] initWithFrame:CGRectMake(0, 504, 402, 280)];
            UIView *detailShade = [[FQVShortVideoGradientLayerView alloc] initWithFrame:CGRectMake(0, 0, 402, 159)];
            [self.fixture.list.view addSubview:topShade]; [self.fixture.list.view addSubview:bottomShade]; [detail.view addSubview:detailShade];
            topShade.alpha = 0.8; bottomShade.alpha = 0.6; detailShade.alpha = 0.8;
            HGWritePreference(@"shade.top", @0.5); HGWritePreference(@"shade.bottom", @0.25); HGWritePreference(@"shade.enabled", @YES);
            for (NSUInteger n = 0; n < 5; n++) { topShade.alpha = 0.8; bottomShade.alpha = 0.6; [topShade layoutSubviews]; [bottomShade layoutSubviews]; }
            HGCheck(HGUnitClose(topShade.alpha, 0.4) && HGUnitClose(bottomShade.alpha, 0.15), @"Shade scaling accumulated or confused top and bottom");
            HGApplyViewing(detailShade); HGCheck(HGUnitClose(detailShade.alpha, 0.8), @"Home shade setting leaked into independent detail");
            HGWritePreference(@"detail.shade.enabled", @YES); HGWritePreference(@"detail.shade.top", @0.25); HGApplyViewing(detailShade);
            HGCheck(HGUnitClose(detailShade.alpha, 0.2), @"Detail shade override did not apply");
            [self.fixture.list.view addSubview:detailShade];
            HGCheck(HGUnitClose(detailShade.alpha, 0.4), @"Reused shade retained detail styling on home");
            [detail.view addSubview:detailShade];
            HGCheck(HGUnitClose(detailShade.alpha, 0.2), @"Reused shade did not regain detail styling");
            HGWritePreference(@"profiles.enabled", @NO); HGApplyViewing(detailShade);
            HGCheck(HGUnitClose(detailShade.alpha, 0.4), @"Disabling independent profiles did not restore common shade settings");
            HGWritePreference(@"enabled", @NO); HGApplyViewing(topShade); HGApplyViewing(bottomShade); HGApplyViewing(detailShade);
            HGCheck(HGUnitClose(topShade.alpha, 0.8) && HGUnitClose(bottomShade.alpha, 0.6) && HGUnitClose(detailShade.alpha, 0.8), @"Master disable failed to restore native shade alpha");
            HGCheck(rectClose(bottomShade.frame, CGRectMake(0, 504, 402, 280)), @"Viewing features changed native shade geometry");
            HGWritePreference(@"enabled", @YES); bottomShade.alpha = 0;
            HGWritePreference(@"shade.enabled", @NO); HGApplyViewing(bottomShade);
            HGCheck(HGUnitClose(bottomShade.alpha, 0), @"Disabling shade revived a host-faded overlay");
            bottomShade.alpha = 0.6;
            [cleanHeader removeFromSuperview]; [detailCaption removeFromSuperview]; [topShade removeFromSuperview]; [bottomShade removeFromSuperview]; [detailShade removeFromSuperview];
            SSFixtureLandscapeTarget *nativeTarget = [SSFixtureLandscapeTarget new], *wrongTarget = [SSFixtureLandscapeTarget new]; wrongTarget.offscreen = YES;
            UIView *offscreenCell = [[FQVShortVideoCell alloc] initWithFrame:CGRectMake(0, 1000, 402, 784)];
            [detail.view insertSubview:offscreenCell atIndex:0];
            UIButton *wrongNative = [UIButton buttonWithType:UIButtonTypeSystem]; wrongNative.frame = CGRectMake(0, 0, 72, 32);
            [wrongNative addTarget:wrongTarget action:@selector(enterFullScreen:) forControlEvents:UIControlEventTouchUpInside]; [offscreenCell addSubview:wrongNative];
            UIButton *exitNative = [UIButton buttonWithType:UIButtonTypeSystem]; exitNative.frame = CGRectMake(0, 110, 72, 32);
            [exitNative setTitle:@"退出全屏" forState:UIControlStateNormal]; [exitNative addTarget:nativeTarget action:@selector(exitFullScreen:) forControlEvents:UIControlEventTouchUpInside];
            [detail.view addSubview:exitNative];
            UIButton *native = [UIButton buttonWithType:UIButtonTypeSystem]; native.frame = CGRectMake(0, 150, 72, 32); native.hidden = YES;
            [native addTarget:nativeTarget action:@selector(enterFullScreen:) forControlEvents:UIControlEventTouchUpInside]; [detail.view addSubview:native];
            HGCheck(!HGBool(@"landscape.enabled"), @"Native landscape entry enabled by default");
            HGWritePreference(@"landscape.enabled", @YES); HGRefreshLandscape(detail);
            UIButton *proxy = (id)[detail.view viewWithTag:0x48474C];
            HGCheck(proxy && !proxy.hidden, @"Hidden native landscape button did not gain a supplementary entry");
            HGWritePreference(@"clean.caption", @NO);
            UIView *placementCaption = [[SSShortVideoSingleSeriesInfoLeftContainerView alloc] initWithFrame:CGRectMake(16, 645, 282, 80)];
            [detail.view addSubview:placementCaption]; placementCaption.hidden = NO;
            TTPlayerView *picture = [[TTPlayerView alloc] initWithFrame:CGRectMake(0, 278.9, detail.view.bounds.size.width, 226.1)];
            [detail.view addSubview:picture]; HGRefreshLandscape(detail);
            HGCheck(closeTo(CGRectGetMidX(proxy.frame), CGRectGetMidX(detail.view.bounds)), @"Full-watch entry was not horizontally centered");
            CGPoint fixedAnchor = [detail.view convertPoint:CGPointMake(CGRectGetMidX(detail.view.window.bounds), detail.view.window.bounds.size.height * 0.6) fromView:detail.view.window];
            HGCheck(closeTo(CGRectGetMinY(proxy.frame), fixedAnchor.y), @"Full-watch entry did not use its fixed screen anchor");
            HGCheck(!CGRectIntersectsRect(proxy.frame, picture.frame) && !CGRectIntersectsRect(proxy.frame, placementCaption.frame), @"Full-watch entry covered picture or captions");
            CGRect stableFrame = proxy.frame;
            picture.frame = detail.view.bounds; HGRefreshLandscape(detail);
            HGCheck(rectClose(proxy.frame, stableFrame), @"Video aspect ratio moved the full-watch entry");
            HGCheck(!CGRectIntersectsRect(proxy.frame, placementCaption.frame), @"Portrait full-watch entry overlapped caption");
            UIScrollView *paging = [[UIScrollView alloc] initWithFrame:detail.view.bounds];
            paging.contentSize = CGSizeMake(paging.bounds.size.width, paging.bounds.size.height * 3);
            [detail.view addSubview:paging]; [paging addSubview:picture]; [paging addSubview:placementCaption];
            for (NSInteger offset = 0; offset <= 900; offset += 150) {
                paging.contentOffset = CGPointMake(0, offset);
                placementCaption.frame = CGRectMake(16, 698 + offset % 44, 282, 50);
                native.frame = CGRectMake(157, 525 + offset, 88, 28);
                HGRefreshLandscape(detail);
                HGCheck(rectClose(proxy.frame, stableFrame), @"Scrolling or caption/native frame changes moved the full-watch entry");
            }
            for (NSInteger pass = 0; pass < 5; pass++) HGRefreshLandscape(detail);
            HGCheck(rectClose(proxy.frame, stableFrame) && rectClose(picture.frame, detail.view.bounds), @"Entry placement drifted or changed player geometry");
            [picture removeFromSuperview]; [placementCaption removeFromSuperview]; [paging removeFromSuperview];
            native.frame = CGRectMake(0, 150, 72, 32);
            [proxy sendActionsForControlEvents:UIControlEventTouchUpInside];
            HGCheck(HGLandscapeCalls == 1 && HGLandscapeWrongCalls == 0 && HGLandscapeExitCalls == 0, @"Landscape forwarded to exit action or a different video");
            HGCheck(native.hidden, @"Supplementary action changed native control visibility");
            native.hidden = NO; HGRefreshLandscape(detail); HGCheck(proxy.hidden, @"Visible native landscape button was duplicated");
            [native removeTarget:nativeTarget action:@selector(enterFullScreen:) forControlEvents:UIControlEventTouchUpInside];
            [native addTarget:nativeTarget action:@selector(onButtonTap:) forControlEvents:UIControlEventTouchUpInside];
            native.frame = CGRectMake(157, 525, 88, 28);
            UIView *labelWrapper = [[UIView alloc] initWithFrame:native.bounds];
            UILabel *fullWatch = [[UILabel alloc] initWithFrame:CGRectMake(30, 5.7, 48, 17)];
            fullWatch.attributedText = [[NSAttributedString alloc] initWithString:@"全屏观看"];
            [labelWrapper addSubview:fullWatch]; [native addSubview:labelWrapper];
            native.hidden = YES; HGRefreshLandscape(detail);
            HGCheck(!proxy.hidden, @"FLEX native watch-fullscreen UILabel was not identified");
            [proxy sendActionsForControlEvents:UIControlEventTouchUpInside];
            HGCheck(HGLandscapeCalls == 2 && HGLandscapeWrongCalls == 0, @"Opaque native action was not forwarded using descendant full-watch label");
            HGCheck([HGLandscapeDiagnosticText() containsString:@"全屏观看"], @"Selected native full-watch control was absent from diagnostic");
            native.hidden = NO; HGRefreshLandscape(detail);
            HGCheck(proxy.hidden, @"FLEX native full-watch control was duplicated");
            [native removeTarget:nativeTarget action:@selector(onButtonTap:) forControlEvents:UIControlEventTouchUpInside];
            [native addTarget:nativeTarget action:@selector(exitFullScreen:) forControlEvents:UIControlEventTouchUpInside];
            UIButton *validFallback = [UIButton buttonWithType:UIButtonTypeSystem]; validFallback.hidden = YES;
            [validFallback addTarget:nativeTarget action:@selector(enterFullScreen:) forControlEvents:UIControlEventTouchUpInside];
            [detail.view addSubview:validFallback];
            [proxy sendActionsForControlEvents:UIControlEventTouchUpInside];
            HGCheck(HGLandscapeExitCalls == 0 && HGLandscapeCalls == 3, @"Full-watch text bypassed exit-action exclusion");
            [validFallback removeFromSuperview];
            HGWritePreference(@"landscape.enabled", @NO); HGRefreshLandscape(detail);
            HGCheck(![detail.view viewWithTag:0x48474C], @"Disabling native landscape entry left an overlay");
            [offscreenCell removeFromSuperview]; [exitNative removeFromSuperview]; [native removeFromSuperview];
            [detail.view removeFromSuperview]; [detail removeFromParentViewController];
            HGCheck(!HGFixtureBottomImage.hidden && !HGFixtureBottomBlur.hidden, @"Native distribution background was modified");
            HGCheck([HGFixtureBottom.backgroundColor isEqual:UIColor.grayColor] && [HGFixtureBottomParent.backgroundColor isEqual:UIColor.grayColor], @"Native distribution color changed");
            HGCheck([self.fixture.view.backgroundColor isEqual:UIColor.grayColor] && [self.fixture.list.view.backgroundColor isEqual:UIColor.grayColor], @"Controller canvas was modified");
            HGCheck(!HGFixtureIcon.hidden && !HGFixtureBottomLabel.hidden, @"Bottom cleanup removed navigation content");
            [self checkTabHeight:50];
            [self checkSettingsState:@"正在运行"]; [self checkSliderMargins];
            UITableViewController *settingsRoot = [self makeSettings];
            HGCheck([settingsRoot numberOfSectionsInTableView:settingsRoot.tableView] == 3 && [settingsRoot tableView:settingsRoot.tableView numberOfRowsInSection:1] == 4, @"Settings root still expands repeated profile controls");
            UINavigationController *settingsNav = [[UINavigationController alloc] initWithRootViewController:settingsRoot];
            [settingsRoot tableView:settingsRoot.tableView didSelectRowAtIndexPath:[NSIndexPath indexPathForRow:0 inSection:1]];
            HGCheck(settingsNav.viewControllers.count == 2 && [[settingsNav.topViewController valueForKey:@"settingsPage"] isEqual:@"home"], @"Settings category failed to open its subpage");
            SSSettingViewController *nativeSettings = [[SSSettingViewController alloc] initWithStyle:UITableViewStyleInsetGrouped];
            [nativeSettings viewDidLayoutSubviews]; UIView *originalEntry = nativeSettings.tableView.tableHeaderView;
            HGCheck(originalEntry && [NSStringFromClass(originalEntry.class) isEqualToString:@"HGSettingsHeader"], @"Native settings entry missing");
            nativeSettings.tableView.tableHeaderView = nil; // Detach before reparenting; UITableView removes its previous header on replacement.
            UIView *hostWrapper = [[UIView alloc] initWithFrame:originalEntry.frame]; [hostWrapper addSubview:originalEntry];
            nativeSettings.tableView.tableHeaderView = hostWrapper;
            [nativeSettings viewDidLayoutSubviews]; [nativeSettings viewDidLayoutSubviews];
            HGCheck(nativeSettings.tableView.tableHeaderView == hostWrapper && originalEntry.superview == hostWrapper, @"Reused native settings header gained a repeated plugin entry");
            HGCheck(method_getImplementation(class_getInstanceMethod(SSTabBarTextButton.class, @selector(setFrame:))) == HGButtonFrameBeforeLoad, @"Native tab frame method was hooked");
            CGFloat height = self.fixture.collection.superview.bounds.size.height - 90;
            HGCheck(closeTo(self.fixture.collection.bounds.size.height, height), @"Hotfix changed the native feed viewport");
            UICollectionViewLayout *layout = self.fixture.collection.collectionViewLayout;
            CGRect page = [layout layoutAttributesForItemAtIndexPath:[NSIndexPath indexPathForItem:1 inSection:0]].frame;
            HGCheck(closeTo(page.origin.y, 784) && closeTo(page.size.height, 784), @"Hotfix changed native page attributes");
            HGCheck(closeTo(layout.collectionViewContentSize.height, 784 * 3), @"Hotfix changed native content size");
            for (SSTabBarTextButton *button in self.fixture.bar.buttons) [button sendActionsForControlEvents:UIControlEventTouchUpInside];
            HGCheck(self.fixture.taps == 3, @"Original tab actions lost");
            HGCheck(!HGBool(@"tab.layout.enabled"), @"Allocation unexpectedly enabled by default");
            HGCheck(method_getImplementation(class_getInstanceMethod(FQVPlayer.class, @selector(setFrame:))) == HGPlayerFrameBeforeLoad, @"Player frame method was hooked");
            HGCheck(closeTo(page.origin.y, 784) && closeTo(layout.collectionViewContentSize.height, 2352), @"Inactive allocation modified layout results");
            HGWritePreference(@"video.extend", @YES);
            HGCheck(!HGBool(@"video.extend"), @"Saved fullscreen setting bypassed hotfix isolation");
            SSTabBar *bar = self.fixture.bar;
            SSTabBarTextButton *first = self.fixture.bar.buttons.firstObject;
            first.label.font = [UIFont systemFontOfSize:20];
            HGWritePreference(@"tab.textScale", @0.7); [first layoutSubviews];
            HGCheck(closeTo(first.label.font.pointSize, 14), @"Tab text size slider ineffective");
            for (NSUInteger n = 0; n < 10; n++) { first.label.font = [UIFont systemFontOfSize:20]; [first layoutSubviews]; }
            HGCheck(closeTo(first.label.font.pointSize, 14), @"Tab host resets defeated font size");
            HGWritePreference(@"tab.textScale", @1); [first layoutSubviews];
            HGCheck(closeTo(first.label.font.pointSize, 20), @"Tab text size did not restore");
            HGWritePreference(@"tab.appearance.enabled", @YES); HGWritePreference(@"tab.appearance.height", @62);
            [bar layoutSubviews];
            UIVisualEffectView *appearance = (id)[bar viewWithTag:0x48474A];
            HGCheck(appearance && [appearance.effect isKindOfClass:UIBlurEffect.class], @"Optional bottom blur missing");
            HGCheck(closeTo(appearance.frame.size.height, 84) && closeTo(appearance.frame.origin.y, 0), @"Inactive allocation left a black strip above the blur");
            HGCheck(closeTo(bar.bounds.size.height, 84), @"Appearance changed native tab allocation");
            HGCheck(closeTo(bar.oldBlur.layer.opacity, 0) && closeTo(bar.oldImage.layer.opacity, 0), @"Original paint remained over custom blur");
            HGCheck([first pointInside:CGPointMake(65, 36) withEvent:nil], @"Blur caption moved outside native click area");
            HGWritePreference(@"tab.appearance.height", @84); [bar layoutSubviews];
            HGCheck(closeTo(appearance.frame.size.height, 84), @"Appearance height did not update");
            HGWritePreference(@"tab.appearance.enabled", @NO); [bar layoutSubviews];
            HGCheck(![bar viewWithTag:0x48474A] && closeTo(bar.oldBlur.layer.opacity, 1) && closeTo(bar.oldImage.layer.opacity, 1), @"Native paint failed to restore");
            [self checkTabHeight:50];
            HGWritePreference(@"tab.layout.enabled", @YES); HGInitializePreferences();
            HGCheck(!HGBool(@"tab.layout.enabled"), @"Diagnostic startup reactivated a hanging previous session");
            HGWritePreference(@"tab.appearance.height", @62); HGWritePreference(@"tab.layout.enabled", @YES);
            [bar layoutSubviews]; [self.fixture.collection layoutIfNeeded];
            CGFloat tabTop = self.window.bounds.size.height - 62;
            HGCheck(closeTo(bar.frame.origin.y, tabTop) && closeTo(bar.bounds.size.height, 62), @"Tab-only height adjustment failed");
            HGCheck(closeTo(self.fixture.collection.bounds.size.height, 784), @"Isolation modified native viewport height");
            HGCheck(closeTo(layout.collectionViewContentSize.height, 784 * 3), @"Isolation modified content height");
            HGCheck(method_getImplementation(class_getInstanceMethod(FQVCollectionView.class, @selector(setFrame:))) == HGFeedFrameBeforeLoad, @"Isolation installed a viewport frame hook");
            HGCheck(method_getImplementation(class_getInstanceMethod(HGFixtureLayout.class, @selector(layoutAttributesForItemAtIndexPath:))) == HGItemBeforeLoad, @"Isolation remapped page attributes");
            HGCheck(method_getImplementation(class_getInstanceMethod(HGFixtureLayout.class, @selector(collectionViewContentSize))) == HGSizeBeforeLoad, @"Isolation remapped content size");
            HGHostCachesCellHeight = YES; HGNativeCellRejections = 0;
            UICollectionViewCell *cachedCell = self.fixture.collection.visibleCells.firstObject;
            for (NSUInteger pass = 0; pass < 5; pass++) [cachedCell layoutSubviews];
            HGHostCachesCellHeight = NO;
            HGCheck(HGNativeCellRejections == 0, @"Cached native cell height is rejected repeatedly while allocation rewrites content geometry");
            HGCheck(closeTo(HGProjectedPlayer.bounds.size.height, 784), @"Isolation changed cached player geometry");
            HGCheck(closeTo(CGRectGetMaxY(HGReclaimedEntry.frame), 784), @"Isolation relocated native episode entry");
            [self.fixture.collection setContentOffset:CGPointMake(0, 784) animated:NO];
            for (NSUInteger pass = 0; pass < 12; pass++) {
                HGWritePreference(@"tab.appearance.height", pass % 2 ? @70 : @62);
                [self.fixture viewDidLayoutSubviews]; [bar layoutSubviews];
                HGCheck(closeTo(bar.bounds.size.height, pass % 2 ? 70 : 62), @"Host reset defeated isolated tab height");
                HGCheck(closeTo(self.fixture.collection.contentOffset.y, 784), @"Isolated height changed native episode offset");
            }
            HGHeightBeginAttempt();
            for (NSUInteger pass = 0; pass < 125; pass++) HGRecordHeightLayout(bar, @selector(layoutSubviews));
            HGCheck([HGHeightDiagnosticText() containsString:@"250 ms"] && HGBool(@"tab.layout.enabled"), @"Passive diagnostic failed to record or silently disabled height");
            HGInitializePreferences(); [bar layoutSubviews];
            HGCheck([HGHeightDiagnosticText() containsString:@"250 ms"] && !HGBool(@"tab.layout.enabled"), @"Restart lost diagnostic trace or reactivated height");
            HGCheck(closeTo(bar.bounds.size.height, 84), @"Isolated tab height did not restore");
            [self.fixture.collection setContentOffset:CGPointZero animated:NO]; [self.fixture.collection layoutIfNeeded];
            HGWritePreference(@"tab.appearance.height", @84); [self checkTabHeight:50];
            for (NSUInteger pass = 0; pass < 8; pass++) {
                HGWritePreference(@"tab.appearance.enabled", @YES); [bar layoutSubviews];
                UIVisualEffectView *full = (id)[bar viewWithTag:0x48474A];
                HGCheck(rectClose(full.frame, bar.bounds), @"Returning to home left a partial blur background");
                HGCheck(bar.subviews.count == 4, @"Black filler remains in the native tab");
                HGWritePreference(@"tab.appearance.enabled", @NO); [bar layoutSubviews];
                HGCheck(bar.subviews.count == 3 && closeTo(bar.oldImage.layer.opacity, 1), @"Native background restoration failed on return");
            }
            HGWritePreference(@"right.scale", scales[0]);
        } else if (self.phase <= scales.count) {
            double expected = [scales[self.phase - 1] doubleValue];
            NSUInteger itemIndex = 0;
            for (UIView *item in self.fixture.right.items) {
                HGCheck(closeTo(item.center.y, itemIndex * 74 + 31), @"Native interaction center was overwritten");
                CGFloat center = 284 - (4 * 62 * expected + 3 * HGNumber(@"right.gap")) + 31 * expected + itemIndex * (62 * expected + HGNumber(@"right.gap"));
                HGCheck(closeTo(HGVisualY(item), center), @"Right visual spacing was overwritten by host layout");
                CGPoint touch = CGPointMake(23, center);
                UIView *hit = [self.fixture.right hitTest:touch withEvent:nil];
                                HGCheck(hit == item || [hit isDescendantOfView:item], @"Compact visual control touch mapped to wrong item");
                HGCheck([hit isKindOfClass:UIButton.class], @"Native action button not reached");
                CGPoint physical = [self.fixture.right convertPoint:touch toView:self.window];
                CGPoint tracking = [hit convertPoint:physical fromView:self.window];
                HGCheck([hit pointInside:tracking withEvent:nil], @"Real window touch coordinate rejected by native button");
                NSUInteger before = HGRightActionCount;
                [(UIControl *)hit sendActionsForControlEvents:UIControlEventTouchUpInside];
                HGCheck(HGRightActionCount == before + 1, @"Original right control action was lost");
                itemIndex++;
                HGCheck(closeTo(item.transform.a, expected), @"Right visual scaling not applied or accumulated");
                HGCheck(closeTo(item.transform.d, expected), @"View scaling differed across axes");
                HGCheck(closeTo(item.bounds.size.width, 46) && closeTo(item.bounds.size.height, 62), @"Scaling resized native hit bounds");
            }
            HGCheck(HGRightPasses < 150 && HGBarPasses < 150, @"Layouts failed to converge");
            if (self.phase < scales.count) HGWritePreference(@"right.scale", scales[self.phase]);
            else HGWritePreference(@"tab.backgroundHeight", @62);
        } else if (self.phase == 6) {
            [self checkTabHeight:28]; HGWritePreference(@"tab.backgroundHeight", @84);
        } else if (self.phase == 7) {
            [self checkTabHeight:50]; HGWritePreference(@"tab.backgroundHeight", @84);
        } else if (self.phase == 8) {
            [self checkTabHeight:50]; HGWritePreference(@"right.comment", @NO);
        } else if (self.phase == 9) {
            HGCheck(self.fixture.right.items[1].hidden, @"Right visibility switch did not hide comment");
            HGCheck(closeTo(HGVisualY(self.fixture.right.items[0]), 284 - (3 * 62 * HGNumber(@"right.scale") + 2 * HGNumber(@"right.gap")) + 31 * HGNumber(@"right.scale")), @"Visible right items did not compact");
            HGWritePreference(@"enabled", @NO);
        } else {
            HGCheck(!self.fixture.bar.oldBlur.hidden && !self.fixture.bar.oldImage.hidden, @"Tab backgrounds did not restore");
            HGCheck(closeTo(self.fixture.bar.bounds.size.height, 84), @"Original tab frame did not restore");
            HGCheck(closeTo(self.fixture.collection.bounds.size.height, self.fixture.list.view.bounds.size.height - 90), @"Feed viewport did not restore");
            for (UIView *item in self.fixture.right.items) HGCheck(CGAffineTransformIsIdentity(item.transform), @"Right transform did not restore");
            HGCheck(!HGFixtureBottomImage.hidden && !HGFixtureBottomBlur.hidden, @"Bottom materials failed to restore when disabled");
            HGCheck([self.fixture.list.view.backgroundColor isEqual:UIColor.grayColor], @"Playback canvas did not restore");
            HGCheck([HGFixtureBottomParent.backgroundColor isEqual:UIColor.grayColor], @"Bottom parent color failed to restore");
            for (CALayer *layer in self.fixture.bar.layer.superlayer.sublayers)
                HGCheck(![layer.name isEqualToString:@"HGK.nativeTabUnderlay"], @"Underlay failed to restore on disable");
            HGCheck(CATransform3DIsIdentity(self.fixture.collection.layer.sublayerTransform), @"Video projection did not restore");
            HGCheck(self.fixture.collection.layer.mask == nil, @"Projection mask did not restore");
            HGCheck(CATransform3DIsIdentity(HGProjectedControls.layer.sublayerTransform), @"Metadata compensation did not restore");
            [self checkSettingsState:@"已关闭"];
            HGSteadyRightPasses = HGRightPasses; HGSteadyButtonPasses = HGButtonPasses;
            HGWritePreference(@"enabled", @YES);
            for (NSUInteger n = 0; n < 160; n++) [self.fixture.right layoutSubviews];
            HGCheck(HGEnabled(), @"Disabled layout protection still switched enhancement off");
            HGCheck(!HGSafetyPaused(), @"Disabled protection still paused layout");
            HGDidTripSafety = HGSafetyPaused();
            [self checkSettingsState:@"正在运行"];
            HGWritePreference(@"enabled", @YES);
            HGCheck(HGEnabled() && !HGSafetyPaused(), @"Explicit retry did not reset pause");
            HGCheck(HGSafetyReason().length > 0, @"Explicit retry deleted historical record");
            [self performSelector:@selector(finishAfterRecovery) withObject:nil afterDelay:0.3]; return;
        }
        if (self.phase < 9) dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.08 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            // Host resets every item after normal layout callbacks, including the first cold appearance.
            for (UIView *item in self.fixture.right.items) item.transform = CGAffineTransformIdentity;
        });
        self.phase++;
        [self performSelector:@selector(runPhase) withObject:nil afterDelay:0.18];
    } @catch (NSException *exception) { HGFinish(exception.reason); }
}
@end
__attribute__((constructor))
static void HGRecordNativeMethods(void) {
    HGTabFrameOriginal = method_getImplementation(class_getInstanceMethod(SSTabBar.class, @selector(setFrame:)));
    HGTabLayoutOriginal = method_getImplementation(class_getInstanceMethod(SSTabBar.class, @selector(layoutSubviews)));
    HGButtonFrameBeforeLoad = method_getImplementation(class_getInstanceMethod(SSTabBarTextButton.class, @selector(setFrame:)));
    HGFeedFrameBeforeLoad = method_getImplementation(class_getInstanceMethod(FQVCollectionView.class, @selector(setFrame:)));
    HGPlayerFrameBeforeLoad = method_getImplementation(class_getInstanceMethod(FQVPlayer.class, @selector(setFrame:)));
    HGItemBeforeLoad = method_getImplementation(class_getInstanceMethod(HGFixtureLayout.class, @selector(layoutAttributesForItemAtIndexPath:)));
    HGSizeBeforeLoad = method_getImplementation(class_getInstanceMethod(HGFixtureLayout.class, @selector(collectionViewContentSize)));
}
int main(int argc, char *argv[]) {
    @autoreleasepool { return UIApplicationMain(argc, argv, nil, NSStringFromClass(HGRegressionApp.class)); }
}



















