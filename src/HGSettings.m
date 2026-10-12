#import "HGCore.h"
#import <math.h>

static char HGHeaderKey;
@interface HGSettingsController : UITableViewController
@end
@interface HGSettingsHeader : UIView
@property(nonatomic, strong) UIButton *entry;
@property(nonatomic, strong) UIImageView *chevron;
@property(nonatomic, strong) UIView *previousHeader;
@property(nonatomic, weak) UIViewController *presenter;
@end

@implementation HGSettingsHeader
- (instancetype)initWithPresenter:(UIViewController *)presenter previous:(UIView *)previous {
    self = [super initWithFrame:CGRectZero];
    if (self) {
        self.presenter = presenter;
        self.previousHeader = previous;
        self.entry = [UIButton buttonWithType:UIButtonTypeSystem];
        self.entry.backgroundColor = UIColor.secondarySystemGroupedBackgroundColor;
        self.entry.layer.cornerRadius = 12.0;
        self.entry.contentHorizontalAlignment = UIControlContentHorizontalAlignmentLeft;
        self.entry.contentEdgeInsets = UIEdgeInsetsMake(0, 20, 0, 20);
        [self.entry setTitle:@"hgkiller" forState:UIControlStateNormal];
        self.entry.titleLabel.font = [UIFont systemFontOfSize:16];
        [self.entry setTitleColor:UIColor.labelColor forState:UIControlStateNormal];
        self.entry.accessibilityLabel = @"hgkiller 观影设置";
        [self.entry addTarget:self action:@selector(openSettings) forControlEvents:UIControlEventTouchUpInside];
        [self addSubview:self.entry];
        self.chevron = [[UIImageView alloc] initWithImage:[UIImage systemImageNamed:@"chevron.right"]];
        self.chevron.tintColor = UIColor.tertiaryLabelColor;
        self.chevron.contentMode = UIViewContentModeScaleAspectFit;
        self.chevron.userInteractionEnabled = NO;
        [self.entry addSubview:self.chevron];
        if (previous) [self addSubview:previous];
    }
    return self;
}
- (void)layoutSubviews {
    [super layoutSubviews];
    self.entry.frame = CGRectMake(0, 0, CGRectGetWidth(self.bounds), 50);
    self.chevron.frame = CGRectMake(CGRectGetWidth(self.bounds) - 36, 17, 16, 16);
    if (self.previousHeader) {
        CGRect frame = self.previousHeader.frame;
        frame.origin = CGPointMake(0, 58);
        frame.size.width = CGRectGetWidth(self.bounds);
        self.previousHeader.frame = frame;
    }
}
- (void)openSettings {
    UIViewController *presenter = self.presenter;
    if (!presenter || presenter.presentedViewController) return;
    HGSettingsController *settings = [[HGSettingsController alloc] initWithStyle:UITableViewStyleInsetGrouped];
    if (presenter.navigationController) [presenter.navigationController pushViewController:settings animated:YES];
    else {
        UINavigationController *navigation = [[UINavigationController alloc] initWithRootViewController:settings];
        settings.navigationItem.rightBarButtonItem =
            [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone target:settings action:@selector(close)];
        [presenter presentViewController:navigation animated:YES completion:nil];
    }
}
@end

static NSArray<NSArray<NSDictionary *> *> *HGRows(void) {
    return @[
        @[@{@"key": @"enabled", @"title": @"启用 hgkiller"}],
        @[
            @{@"key": @"right.avatar", @"title": @"显示头像"},
            @{@"key": @"right.collect", @"title": @"显示收藏"},
            @{@"key": @"right.comment", @"title": @"显示评论"},
            @{@"key": @"right.like", @"title": @"显示点赞"},
            @{@"key": @"right.share", @"title": @"显示分享"},
            @{@"key": @"right.scale", @"title": @"右侧控件大小", @"slider": @YES}
        ],
        @[
            @{@"key": @"tab.glass", @"title": @"悬浮液态玻璃底栏"},
            @{@"key": @"tab.height", @"title": @"底栏高度", @"slider": @YES, @"unit": @"pt", @"min": @44, @"max": @80},
            @{@"key": @"video.extend", @"title": @"视频区域扩展（暂不可用）", @"disabled": @YES},
            @{@"key": @"video.fillPortrait", @"title": @"竖屏裁切铺满（暂不可用）", @"disabled": @YES}
        ],
        @[
            @{@"key": @"top.enabled", @"title": @"缩小顶部文字"},
            @{@"key": @"top.scale", @"title": @"顶部文字大小", @"slider": @YES}
        ],
        @[@{@"title": @"恢复默认设置", @"action": @"reset"},
          @{@"title": @"适配信息", @"action": @"diagnostics"}]
    ];
}
@implementation HGSettingsController
- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"hgkiller";
    self.tableView.backgroundColor = UIColor.systemGroupedBackgroundColor;
}
- (void)close { [self dismissViewControllerAnimated:YES completion:nil]; }
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView { return HGRows().count; }
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section { return HGRows()[section].count; }
- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    return @[@"观影增强", @"右侧控件", @"底栏与视频区域", @"顶部文字", @"其他"][section];
}
- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section {
    switch (section) {
        case 0: return @"关闭后恢复 hgkiller 调整的布局。检测到布局循环时会自动关闭增强，重启应用后再启用。";
        case 1: return @"关闭某项后自动收紧排列；大小可调为 55%–100%。";
        case 2: return @"为排查卡死，本版暂停视频扩展和裁切，保留原播放器与分页。底栏高度和液态玻璃仍可调整。";
        case 3: return @"调整首页顶部分类与搜索文字，保留原来的入口。";
        default: return @"hgkiller 0.1.2 · 红果短剧 7.3.9 适配";
    }
}
- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)path {
    return [HGRows()[path.section][path.row][@"slider"] boolValue] ? 84.0 : 50.0;
}
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)path {
    NSDictionary *row = HGRows()[path.section][path.row];
    UITableViewCell *cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:nil];
    cell.selectionStyle = UITableViewCellSelectionStyleNone;
    cell.textLabel.text = row[@"title"];
    NSString *key = row[@"key"];
    NSInteger tag = path.section * 100 + path.row;
    if ([row[@"slider"] boolValue]) {
        cell.textLabel.text = nil;
        CGFloat width = CGRectGetWidth(tableView.bounds) - 40.0;
        UILabel *title = [[UILabel alloc] initWithFrame:CGRectMake(16, 10, MAX(100, width - 32), 22)];
        title.text = [NSString stringWithFormat:[row[@"unit"] isEqualToString:@"pt"] ? @"%@  %.0f pt" : @"%@  %.0f%%", row[@"title"], HGNumber(key) * ([row[@"unit"] isEqualToString:@"pt"] ? 1 : 100)];
        title.font = [UIFont systemFontOfSize:16];
        title.autoresizingMask = UIViewAutoresizingFlexibleWidth;
        title.tag = 901;
        [cell.contentView addSubview:title];
        UISlider *slider = [[UISlider alloc] initWithFrame:CGRectMake(16, 38, MAX(100, width - 32), 34)];
        slider.autoresizingMask = UIViewAutoresizingFlexibleWidth;
        slider.minimumValue = row[@"min"] ? [row[@"min"] floatValue] : 0.55;
        slider.maximumValue = row[@"max"] ? [row[@"max"] floatValue] : 1.0;
        slider.value = HGNumber(key);
        slider.continuous = NO;
        slider.tag = tag;
        slider.accessibilityLabel = row[@"title"];
        [slider addTarget:self action:@selector(sliderChanged:) forControlEvents:UIControlEventValueChanged];
        [cell.contentView addSubview:slider];
    } else if (key) {
        UISwitch *toggle = [UISwitch new];
        toggle.on = HGBool(key);
        toggle.enabled = ![row[@"disabled"] boolValue];
        if (!toggle.enabled) cell.textLabel.textColor = UIColor.secondaryLabelColor;
        toggle.tag = tag;
        toggle.accessibilityLabel = row[@"title"];
        [toggle addTarget:self action:@selector(switchChanged:) forControlEvents:UIControlEventValueChanged];
        cell.accessoryView = toggle;
    } else {
        cell.selectionStyle = UITableViewCellSelectionStyleDefault;
        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
        if ([row[@"action"] isEqualToString:@"reset"]) cell.textLabel.textColor = UIColor.systemRedColor;
    }
    return cell;
}
- (void)switchChanged:(UISwitch *)sender {
    NSDictionary *row = HGRows()[sender.tag / 100][sender.tag % 100];
    HGWritePreference(row[@"key"], @(sender.on));
    sender.on = HGBool(row[@"key"]);
}
- (void)sliderChanged:(UISlider *)sender {
    NSDictionary *row = HGRows()[sender.tag / 100][sender.tag % 100];
    BOOL points = [row[@"unit"] isEqualToString:@"pt"];
    CGFloat value = points ? round(sender.value) : round(sender.value * 100.0) / 100.0;
    sender.value = value;
    HGWritePreference(row[@"key"], @(value));
    UILabel *title = (id)[sender.superview viewWithTag:901];
    title.text = [NSString stringWithFormat:points ? @"%@  %.0f pt" : @"%@  %.0f%%", row[@"title"], points ? value : value * 100.0];
}
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)path {
    [tableView deselectRowAtIndexPath:path animated:YES];
    NSString *action = HGRows()[path.section][path.row][@"action"];
    if (!action) return;
    if ([action isEqualToString:@"reset"]) {
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"恢复默认设置"
                                                                      message:@"恢复 hgkiller 的开关与缩放比例。"
                                                               preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
        [alert addAction:[UIAlertAction actionWithTitle:@"恢复" style:UIAlertActionStyleDestructive handler:^(UIAlertAction *item) {
            HGResetPreferences();
            [self.tableView reloadData];
        }]];
        [self presentViewController:alert animated:YES completion:nil];
    } else {
        NSArray *missing = HGMissingClasses();
        NSString *version = [NSBundle.mainBundle objectForInfoDictionaryKey:@"CFBundleShortVersionString"] ?: @"未知";
        NSString *glass = NSClassFromString(@"UIGlassEffect") ? @"系统液态玻璃" : @"磨砂兼容模式";
        NSString *message = [NSString stringWithFormat:@"红果版本：%@\n底栏：%@\n%@",
                             version, glass, missing.count ? [@"未找到类：\n" stringByAppendingString:[missing componentsJoinedByString:@"\n"]]
                                                          : @"目标类已加载。\n实际布局仍需真机验证。"];
        if (HGSafetyReason().length) message = [message stringByAppendingFormat:@"\n\n保护记录：%@", HGSafetyReason()];
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"hgkiller 0.1.2"
                                                                      message:message preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:@"好" style:UIAlertActionStyleDefault handler:nil]];
        [self presentViewController:alert animated:YES completion:nil];
    }
}
@end

static UITableView *HGFindSettingsTable(UIView *root) {
    if ([root isKindOfClass:UITableView.class]) return (id)root;
    for (UIView *view in root.subviews) {
        UITableView *found = HGFindSettingsTable(view);
        if (found) return found;
    }
    return nil;
}
static void HGInsertSettingsEntry(UIViewController *controller) {
    UITableView *table = HGFindSettingsTable(controller.view);
    if (!table) return;
    HGSettingsHeader *header = objc_getAssociatedObject(table, &HGHeaderKey);
    if (table.tableHeaderView != header || !header) {
        UIView *previous = table.tableHeaderView;
        header = [[HGSettingsHeader alloc] initWithPresenter:controller previous:previous];
        CGFloat height = 58.0 + (previous ? CGRectGetHeight(previous.frame) : 0.0);
        header.frame = CGRectMake(0, 0, CGRectGetWidth(table.bounds), height);
        objc_setAssociatedObject(table, &HGHeaderKey, header, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        table.tableHeaderView = header;
    } else if (fabs(CGRectGetWidth(header.frame) - CGRectGetWidth(table.bounds)) > 0.5) {
        CGRect frame = header.frame;
        frame.size.width = CGRectGetWidth(table.bounds);
        header.frame = frame;
        table.tableHeaderView = header;
    }
}
void HGInstallSettings(void) {
    HGHookControllerLayout(@"SSSettingViewController", ^(UIViewController *controller) { HGInsertSettingsEntry(controller); });
    SEL appear = @selector(viewWillAppear:);
    HGInstall(NSClassFromString(@"SSSettingViewController"), appear, ^id(IMP original) {
        return ^(UIViewController *controller, BOOL animated) {
            ((void (*)(id, SEL, BOOL))original)(controller, appear, animated);
            HGInsertSettingsEntry(controller);
        };
    });
}
