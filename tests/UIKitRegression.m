#import <UIKit/UIKit.h>
#import "HGCore.h"
#import "HGGeometry.h"
#import <math.h>

static NSUInteger HGBarPasses, HGRightPasses, HGChecks;
static void HGFinish(NSString *error) {
    NSString *path = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES).firstObject
                      stringByAppendingPathComponent:@"hg-results.json"];
    NSDictionary *result = @{@"success": @(!error), @"checks": @(HGChecks),
                             @"tabLayoutPasses": @(HGBarPasses), @"rightLayoutPasses": @(HGRightPasses),
                             @"error": error ?: @""};
    [[NSJSONSerialization dataWithJSONObject:result options:NSJSONWritingPrettyPrinted error:nil] writeToFile:path atomically:YES];
}
static void HGCheck(BOOL condition, NSString *message) {
    HGChecks++;
    if (!condition) @throw [NSException exceptionWithName:@"HGRegressionFailure" reason:message userInfo:nil];
}
static BOOL closeTo(CGFloat a, CGFloat b) { return fabs(a - b) < 0.3; }

@interface SSRootViewController : UIViewController @end
@implementation SSRootViewController @end
@interface SSVideoSeriesFeedViewController : UIViewController @end
@implementation SSVideoSeriesFeedViewController @end
@interface FQVShortVideoListViewController : UIViewController @end
@implementation FQVShortVideoListViewController @end
@interface FQVCollectionView : UICollectionView @end
@implementation FQVCollectionView @end
@interface FQVShortVideoCell : UICollectionViewCell @end
@implementation FQVShortVideoCell @end

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
    // Simulate the hard-coded 402-wide host layout seen in the supplied dump.
    self.caption.frame = CGRectMake(49.6667, 13.6667, 32, 22.6667);
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
    [self.window makeKeyAndVisible];
    HGResetPreferences();
    [self performSelector:@selector(runPhase) withObject:nil afterDelay:0.6];
    return YES;
}
- (void)checkTabHeight:(CGFloat)height {
    SSTabBar *bar = self.fixture.bar;
    HGCheck(closeTo(bar.bounds.size.height, height), @"Configured tab height not applied");
    HGCheck(bar.oldBlur.hidden && bar.oldImage.hidden, @"Old material or gray background image still visible");
    HGCheck(closeTo(bar.row.bounds.size.width, bar.bounds.size.width), @"Native 402pt row was not resized");
    for (NSUInteger index = 0; index < 3; index++) {
        SSTabBarTextButton *button = bar.buttons[index];
        HGRect slot = HGTabButtonRect(bar.bounds.size.width, height, index, 3);
        HGCheck(closeTo(button.frame.origin.x, slot.x) && closeTo(button.bounds.size.width, slot.width), @"Native late frame write overwrote tab slot");
        HGCheck(closeTo(button.caption.center.x, button.bounds.size.width / 2) &&
                closeTo(button.caption.center.y, height / 2), @"Tab caption not centered");
        HGCheck(button.bounds.size.height >= 44, @"Tab touch target below 44pt");
    }
}
- (void)runPhase {
    @try {
        NSArray *scales = @[@0.55, @0.80, @1.0, @0.55, @0.80];
        if (self.phase == 0) {
            [self checkTabHeight:54];
            CGFloat height = self.fixture.collection.superview.bounds.size.height;
            HGCheck(closeTo(self.fixture.collection.bounds.size.height, height), @"Custom non-FlowLayout feed did not extend");
            UICollectionViewLayout *layout = self.fixture.collection.collectionViewLayout;
            CGRect page = [layout layoutAttributesForItemAtIndexPath:[NSIndexPath indexPathForItem:1 inSection:0]].frame;
            HGCheck(closeTo(page.origin.y, height) && closeTo(page.size.height, height), @"Custom layout page stride incorrect");
            HGCheck(closeTo(layout.collectionViewContentSize.height, height * 3), @"Custom layout content size incorrect");
            for (SSTabBarTextButton *button in self.fixture.bar.buttons) [button sendActionsForControlEvents:UIControlEventTouchUpInside];
            HGCheck(self.fixture.taps == 3, @"Original tab actions lost");
            HGWritePreference(@"right.scale", scales[0]);
        } else if (self.phase <= scales.count) {
            double expected = [scales[self.phase - 1] doubleValue];
            for (UIView *item in self.fixture.right.items) {
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
            HGCheck(closeTo(self.fixture.right.items[0].frame.origin.y, 74), @"Visible right items did not compact");
            HGWritePreference(@"enabled", @NO);
        } else {
            HGCheck(!self.fixture.bar.oldBlur.hidden && !self.fixture.bar.oldImage.hidden, @"Tab backgrounds did not restore");
            HGCheck(closeTo(self.fixture.bar.bounds.size.height, 84), @"Original tab frame did not restore");
            HGCheck(closeTo(self.fixture.collection.bounds.size.height, self.fixture.list.view.bounds.size.height - 90), @"Feed viewport did not restore");
            for (UIView *item in self.fixture.right.items) HGCheck(CATransform3DIsIdentity(item.layer.sublayerTransform), @"Right visual scale did not restore");
            HGFinish(nil); return;
        }
        self.phase++;
        [self performSelector:@selector(runPhase) withObject:nil afterDelay:0.18];
    } @catch (NSException *exception) { HGFinish(exception.reason); }
}
@end
int main(int argc, char *argv[]) {
    @autoreleasepool { return UIApplicationMain(argc, argv, nil, NSStringFromClass(HGRegressionApp.class)); }
}
