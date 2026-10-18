#import "HGCore.h"
#import <math.h>

static char HGHeaderKey;
@interface HGSettingsController : UITableViewController
@property(nonatomic, copy) NSString *settingsPage;
- (NSArray<NSArray<NSDictionary *> *> *)settingsRows;
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

@interface HGSliderCell : UITableViewCell
@property(nonatomic, strong) UILabel *caption;
@property(nonatomic, strong) UISlider *slider;
@end
@implementation HGSliderCell
- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)identifier {
    self = [super initWithStyle:style reuseIdentifier:identifier];
    if (self) {
        self.caption = [UILabel new]; self.slider = [UISlider new];
        self.caption.font = [UIFont systemFontOfSize:16];
        self.caption.tag = 901;
        [self.contentView addSubview:self.caption]; [self.contentView addSubview:self.slider];
    }
    return self;
}
- (void)layoutSubviews {
    [super layoutSubviews];
    CGFloat width = MAX(0, CGRectGetWidth(self.contentView.bounds) - 32);
    self.caption.frame = CGRectMake(16, 10, width, 22);
    self.slider.frame = CGRectMake(16, 38, width, 34);
}
@end
static NSString *HGSettingsState(void) {
    if (HGSafetyPaused()) return @"已暂停（布局保护）";
    return HGEnabled() ? @"正在运行" : @"已关闭";
}

static NSArray<NSArray<NSDictionary *> *> *HGAllRows(void) {
    NSMutableArray *sections = [@[
        @[@{@"key": @"enabled", @"title": @"启用 hgkiller"},
          @{@"title": @"运行状态", @"action": @"status"}],
        @[
            @{@"key": @"right.avatar", @"title": @"显示头像"},
            @{@"key": @"right.collect", @"title": @"显示收藏"},
            @{@"key": @"right.comment", @"title": @"显示评论"},
            @{@"key": @"right.like", @"title": @"显示点赞"},
            @{@"key": @"right.share", @"title": @"显示分享"},
            @{@"key": @"right.scale", @"title": @"右侧控件大小", @"slider": @YES},
            @{@"key": @"right.gap", @"title": @"右侧控件间距", @"slider": @YES, @"unit": @"pt", @"min": @0, @"max": @24}
        ],
        @[
            @{@"key": @"tab.textScale", @"title": @"底栏文字大小", @"slider": @YES, @"min": @0.55, @"max": @1.2},
            @{@"key": @"tab.appearance.enabled", @"title": @"深色模糊背景"},
            @{@"key": @"tab.layout.enabled", @"title": @"实际高度调整（仅底栏诊断）"},
            @{@"key": @"tab.appearance.height", @"title": @"底栏高度", @"slider": @YES, @"unit": @"pt", @"min": @62, @"max": @84},

        ],
        @[
            @{@"key": @"top.enabled", @"title": @"缩小顶部文字"},
            @{@"key": @"top.scale", @"title": @"顶部文字大小", @"slider": @YES}
        ],
        @[@{@"key": @"caption.enabled", @"title": @"自定义播放页文案"},
          @{@"key": @"caption.titleScale", @"title": @"剧名文字大小", @"slider": @YES},
          @{@"key": @"caption.descriptionScale", @"title": @"集数、简介与展开文字大小", @"slider": @YES}],
        @[@{@"title": @"恢复默认设置", @"action": @"reset"},
          @{@"title": @"适配信息", @"action": @"diagnostics"},
          @{@"title": @"清除上次保护记录", @"action": @"clearSafety"},
          @{@"title": @"高度诊断记录", @"action": @"heightLog"},
          @{@"title": @"横屏入口诊断", @"action": @"landscapeLog"}]
    ] mutableCopy];
    [sections addObject:@[
        @{@"key": @"profiles.enabled", @"title": @"首页与合集独立配置"},
        @{@"key": @"clean.enabled", @"title": @"一键纯净模式"},
        @{@"key": @"clean.right", @"title": @"纯净时隐藏右侧控件"},
        @{@"key": @"clean.caption", @"title": @"纯净时隐藏剧名与简介"},
        @{@"key": @"clean.header", @"title": @"纯净时隐藏顶部分类"},
        @{@"key": @"clean.distribution", @"title": @"纯净时隐藏观看全集入口"},
        @{@"key": @"shade.enabled", @"title": @"自定义渐变遮罩强度"},
        @{@"key": @"shade.top", @"title": @"顶部遮罩强度", @"slider": @YES, @"min": @0, @"max": @1},
        @{@"key": @"shade.bottom", @"title": @"底部遮罩强度", @"slider": @YES, @"min": @0, @"max": @1}
    ]];
    NSMutableArray *detailRows = [NSMutableArray array];
    for (NSNumber *section in @[@1, @4, @6]) for (NSDictionary *row in sections[section.unsignedIntegerValue]) {
        NSString *key = row[@"key"];
        if ([key isEqualToString:@"profiles.enabled"] || [key isEqualToString:@"clean.header"]) continue;
        NSMutableDictionary *detail = [row mutableCopy]; detail[@"key"] = [@"detail." stringByAppendingString:key];
        detail[@"disabled"] = @(!HGBool(@"profiles.enabled")); [detailRows addObject:detail];
    }
    [sections addObject:detailRows];
    return sections;
}
@implementation HGSettingsController
- (NSArray<NSArray<NSDictionary *> *> *)settingsRows {
    NSArray *all = HGAllRows();
    if ([self.settingsPage isEqualToString:@"home"]) return @[all[1], all[3], all[4], [all[6] subarrayWithRange:NSMakeRange(1, [all[6] count] - 1)]];
    if ([self.settingsPage isEqualToString:@"detail"]) {
        NSMutableArray *right = [NSMutableArray array], *caption = [NSMutableArray array], *viewing = [NSMutableArray array];
        for (NSDictionary *row in all[7]) {
            if ([row[@"key"] hasPrefix:@"detail.right."]) [right addObject:row];
            else if ([row[@"key"] hasPrefix:@"detail.caption."]) [caption addObject:row];
            else [viewing addObject:row];
        }
        return @[right, caption, viewing];
    }
    if ([self.settingsPage isEqualToString:@"tab"]) return @[all[2]];
    if ([self.settingsPage isEqualToString:@"other"]) return @[all[5]];
    return @[all[0], @[
        @{@"title": HGBool(@"profiles.enabled") ? @"首页观影设置" : @"通用观影设置", @"action": @"page.home"},
        @{@"key": @"profiles.enabled", @"title": @"首页与合集独立配置"},
        @{@"title": @"合集观影设置", @"action": @"page.detail", @"disabled": @(!HGBool(@"profiles.enabled"))},
        @{@"key": @"landscape.enabled", @"title": @"补充原生横屏入口"}
    ], @[
        @{@"title": @"底栏设置（诊断）", @"action": @"page.tab"},
        @{@"title": @"诊断与重置", @"action": @"page.other"}
    ]];
}
- (NSString *)pageTitle {
    if ([self.settingsPage isEqualToString:@"home"]) return HGBool(@"profiles.enabled") ? @"首页观影设置" : @"通用观影设置";
    if ([self.settingsPage isEqualToString:@"detail"]) return @"合集观影设置";
    if ([self.settingsPage isEqualToString:@"tab"]) return @"底栏设置（诊断）";
    if ([self.settingsPage isEqualToString:@"other"]) return @"诊断与重置";
    return @"hgkiller";
}
- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = [self pageTitle];
    self.tableView.backgroundColor = UIColor.systemGroupedBackgroundColor;
    [NSNotificationCenter.defaultCenter addObserver:self selector:@selector(preferencesChanged:) name:HGPreferencesDidChangeNotification object:nil];
}
- (void)dealloc { [NSNotificationCenter.defaultCenter removeObserver:self]; }
- (void)preferencesChanged:(NSNotification *)note { self.title = [self pageTitle]; [self.tableView reloadData]; }
- (void)viewWillAppear:(BOOL)animated { [super viewWillAppear:animated]; self.title = [self pageTitle]; [self.tableView reloadData]; }
- (void)close { [self dismissViewControllerAnimated:YES completion:nil]; }
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView { return [self settingsRows].count; }
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section { return [self settingsRows][section].count; }
- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    if ([self.settingsPage isEqualToString:@"home"]) return @[@"右侧控件", @"顶部文字", @"播放文案", @"纯净模式与遮罩"][section];
    if ([self.settingsPage isEqualToString:@"detail"]) return @[@"右侧控件", @"播放文案", @"纯净模式与遮罩"][section];
    if (self.settingsPage.length) return [self pageTitle];
    return @[@"观影增强", @"观影设置", @"其他"][section];
}
- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section {
    if (!self.settingsPage.length) {
        if (section == 0) return @"关闭总开关后恢复插件调整的显示状态。";
        if (section == 1) return @"关闭独立配置时只需设置通用参数；开启后可分别设置首页与合集。补充横屏入口会调用当前视频的原生按钮事件，能否进入横屏仍由红果播放器决定。";
        return @"hgkiller 0.1.23 · 原设置保留";
    }
    if ([self.settingsPage isEqualToString:@"detail"]) return HGBool(@"profiles.enabled") ? @"仅影响合集播放页，保留首页设置。" : @"请先返回首页开启独立配置。";
    if ([self.settingsPage isEqualToString:@"home"]) section = [@[@1, @3, @4, @6][section] unsignedIntegerValue];
    else if ([self.settingsPage isEqualToString:@"tab"]) section = 2;
    else section = 5;
    switch (section) {
        case 0: return @"关闭后恢复 hgkiller 调整的布局。本版本暂时停用布局保护。";
        case 1: return @"关闭某项后自动收紧排列；大小 55%–100%，间距 0–24 pt。首次显示与后续布局统一应用。";
        case 2: return @"诊断版只调整底栏，不扩展视频，不改分页或播放器；原播放占位仍保留，可能有空隙。每次启动默认关闭，方便卡住后重启查看诊断。记录不会自动停用功能。";
        case 3: return @"调整首页顶部分类与搜索文字，保留原来的入口。";
        case 4: return @"剧名与集数、简介、展开分别调整为原字号的 55%–100%。默认原字号，不修改文案容器位置。";
        case 6: return @"纯净模式默认保留观看全集入口，关闭后恢复宿主显示状态。遮罩强度 0%–100%，仅降低原渐变透明度。关闭独立配置时，通用设置同时作用于首页和合集。";
        case 7: return @"开启独立配置后生效；首次开启会复制当前通用设置，再允许单独调整合集的控件、文案、纯净模式与遮罩。顶部分类仅在首页设置。";
        default: return @"hgkiller 0.1.23 · 红果短剧 7.3.9 适配";
    }
}
- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)path {
    return [[self settingsRows][path.section][path.row][@"slider"] boolValue] ? 84.0 : 50.0;
}
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)path {
    NSDictionary *row = [self settingsRows][path.section][path.row];
    UITableViewCell *cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:nil];
    cell.selectionStyle = UITableViewCellSelectionStyleNone;
    cell.textLabel.text = row[@"title"];
    NSString *key = row[@"key"];
    NSInteger tag = path.section * 100 + path.row;
    if ([row[@"slider"] boolValue]) {
        HGSliderCell *sliderCell = [[HGSliderCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:nil];
        cell = sliderCell; cell.selectionStyle = UITableViewCellSelectionStyleNone;
        sliderCell.caption.text = [NSString stringWithFormat:[row[@"unit"] isEqualToString:@"pt"] ? @"%@  %.0f pt" : @"%@  %.0f%%", row[@"title"], HGNumber(key) * ([row[@"unit"] isEqualToString:@"pt"] ? 1 : 100)];
        sliderCell.caption.textColor = HGEnabled() && ![row[@"disabled"] boolValue] ? UIColor.labelColor : UIColor.secondaryLabelColor;
        UISlider *slider = sliderCell.slider;
        slider.minimumValue = row[@"min"] ? [row[@"min"] floatValue] : 0.55;
        slider.maximumValue = row[@"max"] ? [row[@"max"] floatValue] : 1.0;
        slider.value = HGNumber(key); slider.continuous = NO; slider.tag = tag;
        slider.enabled = HGEnabled() && ![row[@"disabled"] boolValue]; slider.accessibilityLabel = row[@"title"];
        [slider addTarget:self action:@selector(sliderChanged:) forControlEvents:UIControlEventValueChanged];
    } else if (key) {
        UISwitch *toggle = [UISwitch new];
        toggle.on = HGBool(key);
        toggle.enabled = ![row[@"disabled"] boolValue] && ([key isEqualToString:@"enabled"] || HGEnabled());
        if (!toggle.enabled) cell.textLabel.textColor = UIColor.secondaryLabelColor;
        toggle.tag = tag;
        toggle.accessibilityLabel = row[@"title"];
        [toggle addTarget:self action:@selector(switchChanged:) forControlEvents:UIControlEventValueChanged];
        cell.accessoryView = toggle;
    } else {
        cell.selectionStyle = UITableViewCellSelectionStyleDefault;
        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
        if ([row[@"disabled"] boolValue]) { cell.selectionStyle = UITableViewCellSelectionStyleNone; cell.textLabel.textColor = UIColor.secondaryLabelColor; }
        if ([row[@"action"] isEqualToString:@"reset"]) cell.textLabel.textColor = UIColor.systemRedColor;
        if ([row[@"action"] isEqualToString:@"status"]) {
            cell.detailTextLabel.text = HGSettingsState();
            cell.detailTextLabel.textColor = HGSafetyPaused() ? UIColor.systemOrangeColor : HGEnabled() ? UIColor.systemGreenColor : UIColor.secondaryLabelColor;
        }
    }
    return cell;
}
- (void)switchChanged:(UISwitch *)sender {
    NSDictionary *row = [self settingsRows][sender.tag / 100][sender.tag % 100];
    HGWritePreference(row[@"key"], @(sender.on));
    sender.on = HGBool(row[@"key"]);
}
- (void)sliderChanged:(UISlider *)sender {
    NSDictionary *row = [self settingsRows][sender.tag / 100][sender.tag % 100];
    BOOL points = [row[@"unit"] isEqualToString:@"pt"];
    CGFloat value = points ? round(sender.value) : round(sender.value * 100.0) / 100.0;
    sender.value = value;
    HGWritePreference(row[@"key"], @(value));
    UILabel *title = (id)[sender.superview viewWithTag:901];
    title.text = [NSString stringWithFormat:points ? @"%@  %.0f pt" : @"%@  %.0f%%", row[@"title"], points ? value : value * 100.0];
}
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)path {
    [tableView deselectRowAtIndexPath:path animated:YES];
    NSDictionary *row = [self settingsRows][path.section][path.row];
    if ([row[@"disabled"] boolValue]) return;
    NSString *action = row[@"action"];
    if (!action) return;
    if ([action hasPrefix:@"page."]) {
        HGSettingsController *page = [[HGSettingsController alloc] initWithStyle:UITableViewStyleInsetGrouped]; page.settingsPage = [action substringFromIndex:5];
        if (self.navigationController) [self.navigationController pushViewController:page animated:YES];
        else {
            page.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone target:page action:@selector(close)];
            [self presentViewController:[[UINavigationController alloc] initWithRootViewController:page] animated:YES completion:nil];
        }
        return;
    }
    if ([action isEqualToString:@"heightLog"] || [action isEqualToString:@"landscapeLog"]) {
        BOOL landscape = [action isEqualToString:@"landscapeLog"];
        UIViewController *detail = [UIViewController new]; detail.title = landscape ? @"横屏入口诊断" : @"高度诊断记录";
        UITextView *text = [[UITextView alloc] initWithFrame:detail.view.bounds];
        text.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        text.editable = NO; text.selectable = YES; text.alwaysBounceVertical = YES;
        text.backgroundColor = UIColor.systemBackgroundColor;
        text.font = [UIFont monospacedSystemFontOfSize:12 weight:UIFontWeightRegular];
        text.textContainerInset = UIEdgeInsetsMake(16, 16, 16, 16); text.text = landscape ? HGLandscapeDiagnosticText() : HGHeightDiagnosticText();
        [detail.view addSubview:text];
        if (self.navigationController) [self.navigationController pushViewController:detail animated:YES];
        else {
            detail.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone target:self action:@selector(close)];
            [self presentViewController:[[UINavigationController alloc] initWithRootViewController:detail] animated:YES completion:nil];
        }
        return;
    }
    if ([action isEqualToString:@"clearSafety"]) { HGClearSafetyRecord(); return; }
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
        NSString *glass = HGBool(@"tab.appearance.enabled") ? @"深色系统模糊" : @"原生全宽背景";
        NSString *message = [NSString stringWithFormat:@"红果版本：%@\n底栏：%@\n%@",
                             version, glass, missing.count ? [@"未找到类：\n" stringByAppendingString:[missing componentsJoinedByString:@"\n"]]
                                                          : @"目标类已加载。\n实际布局仍需真机验证。"];
        message = [message stringByAppendingFormat:@"\n\n当前状态：%@\n布局保护：暂时停用", HGSettingsState()];
        message = [message stringByAppendingFormat:@"\n实际高度调整：%@\n设置高度：%.0f pt", HGBool(@"tab.layout.enabled") ? @"开启" : @"关闭", HGNumber(@"tab.appearance.height")];
        if (HGSafetyReason().length) message = [message stringByAppendingFormat:@"\n\n上次保护记录（历史）：%@", HGSafetyReason()];
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"hgkiller 0.1.23"
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
static HGSettingsHeader *HGFindExistingSettingsHeader(UIView *view) {
    if ([view isKindOfClass:HGSettingsHeader.class]) return (id)view;
    for (UIView *child in view.subviews) {
        HGSettingsHeader *found = HGFindExistingSettingsHeader(child); if (found) return found;
    }
    return nil;
}
static void HGInsertSettingsEntry(UIViewController *controller) {
    UITableView *table = HGFindSettingsTable(controller.view);
    if (!table) return;
    HGSettingsHeader *header = objc_getAssociatedObject(table, &HGHeaderKey);
    HGSettingsHeader *existing = HGFindExistingSettingsHeader(table.tableHeaderView);
    if (existing) {
        existing.presenter = controller; header = existing;
        objc_setAssociatedObject(table, &HGHeaderKey, existing, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        if (table.tableHeaderView != existing) return; // Host wrapped or reused an existing entry.
    }
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
















