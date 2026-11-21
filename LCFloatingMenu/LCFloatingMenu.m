//
//  LCFloatingMenu.m (Minimal Return-Only Edition)
//  Only keeps: draggable edge-snapping floating button, tap to return to LiveContainer,
//  and custom style / size / opacity / appearance settings.
//  Removed: multi-app switcher, drawer panel, PiPManager queries, haptics, auto-updater.
//

#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>
#import <math.h>
#import <stdlib.h>

#import "../LCOrbit/Core/LCOrbitCore.h"
#import "../LCOrbit/Core/LCOrbitHost.h"
#import "../LCOrbit/Core/LCOrbitHostSettings.h"
#import "../LCOrbit/Core/LCOrbitMultitask.h"
#import "../LCOrbit/Core/LCOrbitOverlayManager.h"
#import "../LCOrbit/Core/LCOrbitStorage.h"

typedef NS_ENUM(NSInteger, FMOrbStyle) {
    FMOrbStyleCapsule = 0,
    FMOrbStyleDroplet = 1,
    FMOrbStyleCircle  = 2,
};

typedef NS_ENUM(NSInteger, FMAppearanceMode) {
    FMAppearanceSystem = 0,
    FMAppearanceLight  = 1,
    FMAppearanceDark   = 2,
};

#pragma mark - Preferences Helpers

static inline CGFloat FMClamp(CGFloat v, CGFloat lo, CGFloat hi) {
    return v < lo ? lo : (v > hi ? hi : v);
}

static NSString *FMPrefKey(NSString *key) {
    return [LCOrbitStorage key:key forModule:@"LCFloatingMenu"];
}

static LCOrbitPreferences *FMPrefs(void) {
    return [LCOrbitStorage preferences];
}

static CGFloat FMFloatPref(NSString *key, CGFloat fallback, CGFloat lo, CGFloat hi) {
    id val = [FMPrefs() objectForKey:FMPrefKey(key)];
    if ([val isKindOfClass:NSNumber.class]) {
        return FMClamp((CGFloat)[val doubleValue], lo, hi);
    }
    return fallback;
}

static NSInteger FMIntPref(NSString *key, NSInteger fallback, NSInteger lo, NSInteger hi) {
    id val = [FMPrefs() objectForKey:FMPrefKey(key)];
    if ([val isKindOfClass:NSNumber.class]) {
        NSInteger v = [val integerValue];
        return v < lo ? lo : (v > hi ? hi : v);
    }
    return fallback;
}

static void FMSetNumberPref(NSString *key, NSNumber *value) {
    [FMPrefs() setObject:value forKey:FMPrefKey(key)];
    [FMPrefs() synchronize];
}

static CGFloat FMOrbScale(void) {
    return FMFloatPref(@"orbScale", 1.0, 0.6, 1.8);
}

static FMOrbStyle FMOrbStylePref(void) {
    return (FMOrbStyle)FMIntPref(@"orbHandleStyle", FMOrbStyleCapsule, FMOrbStyleCapsule, FMOrbStyleCircle);
}

static CGFloat FMOrbOpacityPref(void) {
    return FMFloatPref(@"orbOpacity", 0.78, 0.25, 1.0);
}

static FMAppearanceMode FMAppearancePref(void) {
    return (FMAppearanceMode)FMIntPref(@"appearanceMode", FMAppearanceSystem, FMAppearanceSystem, FMAppearanceDark);
}

static BOOL FMOrbRightSidePref(void) {
    id val = [FMPrefs() objectForKey:FMPrefKey(@"orbRightSide")];
    return [val isKindOfClass:NSNumber.class] ? [val boolValue] : YES;
}

static CGFloat FMOrbYRatioPref(void) {
    return FMFloatPref(@"orbYRatio", 0.48, 0.08, 0.92);
}

#pragma mark - Overlay Pass-Through Container

@interface FMOverlayHostView : UIView
@property (nonatomic, copy) void (^onLayout)(void);
@end

@implementation FMOverlayHostView
- (void)layoutSubviews {
    [super layoutSubviews];
    if (self.onLayout) self.onLayout();
}

- (UIView *)hitTest:(CGPoint)point withEvent:(UIEvent *)event {
    for (UIView *sub in [self.subviews reverseObjectEnumerator]) {
        if (sub.hidden || !sub.userInteractionEnabled || sub.alpha <= 0.01) continue;
        CGPoint converted = [self convertPoint:point toView:sub];
        UIView *hit = [sub hitTest:converted withEvent:event];
        if (hit) return hit;
    }
    return nil;
}
@end

#pragma mark - Manager Declaration

@interface FMReturnManager : NSObject
@property (nonatomic, strong) LCOrbitContext *orbitContext;
@property (nonatomic, weak) UIWindow *window;
@property (nonatomic, strong) FMOverlayHostView *hostView;
@property (nonatomic, strong) UIView *orbView;
@property (nonatomic, strong) UIVisualEffectView *blurView;
@property (nonatomic, strong) UIImageView *iconView;
@property (nonatomic, strong) UIWindow *settingsWindow;
@property (nonatomic, weak) UIWindow *previousKeyWindow;
@property (nonatomic, assign) BOOL isDragging;

+ (instancetype)shared;
- (void)installIfPossible;
- (void)refreshUI;
- (void)detachFromScene;
- (void)openSettingsInScene:(UIWindowScene *)scene;
- (void)closeSettings;
@end

#pragma mark - Minimal Style & Size Settings View Controller

@interface FMStyleSettingsViewController : UITableViewController
@property (nonatomic, copy) void (^onDone)(void);
@property (nonatomic, copy) void (^onChange)(void);
@property (nonatomic, strong) UISegmentedControl *styleControl;
@property (nonatomic, strong) UISegmentedControl *appearanceControl;
@property (nonatomic, strong) UISlider *scaleSlider;
@property (nonatomic, strong) UILabel *scaleValueLabel;
@property (nonatomic, strong) UISlider *opacitySlider;
@property (nonatomic, strong) UILabel *opacityValueLabel;
@end

@implementation FMStyleSettingsViewController

- (instancetype)init {
    return [super initWithStyle:UITableViewStyleInsetGrouped];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"悬浮返回按钮";
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc]
        initWithBarButtonSystemItem:UIBarButtonSystemItemDone
                             target:self
                             action:@selector(doneTapped)];

    self.styleControl = [[UISegmentedControl alloc] initWithItems:@[@"胶囊", @"水滴", @"圆球"]];
    self.styleControl.selectedSegmentIndex = FMOrbStylePref();
    [self.styleControl addTarget:self action:@selector(styleChanged:) forControlEvents:UIControlEventValueChanged];

    self.appearanceControl = [[UISegmentedControl alloc] initWithItems:@[@"跟随系统", @"浅色", @"深色"]];
    self.appearanceControl.selectedSegmentIndex = FMAppearancePref();
    [self.appearanceControl addTarget:self action:@selector(appearanceChanged:) forControlEvents:UIControlEventValueChanged];

    self.scaleSlider = [UISlider new];
    self.scaleSlider.minimumValue = 0.6f;
    self.scaleSlider.maximumValue = 1.8f;
    self.scaleSlider.value = (float)FMOrbScale();
    [self.scaleSlider addTarget:self action:@selector(scaleChanged:) forControlEvents:UIControlEventValueChanged];

    self.scaleValueLabel = [UILabel new];
    self.scaleValueLabel.font = [UIFont monospacedDigitSystemFontOfSize:13 weight:UIFontWeightMedium];
    self.scaleValueLabel.textColor = UIColor.secondaryLabelColor;
    self.scaleValueLabel.textAlignment = NSTextAlignmentRight;
    self.scaleValueLabel.text = [NSString stringWithFormat:@"%.2fx", self.scaleSlider.value];

    self.opacitySlider = [UISlider new];
    self.opacitySlider.minimumValue = 0.25f;
    self.opacitySlider.maximumValue = 1.0f;
    self.opacitySlider.value = (float)FMOrbOpacityPref();
    [self.opacitySlider addTarget:self action:@selector(opacityChanged:) forControlEvents:UIControlEventValueChanged];

    self.opacityValueLabel = [UILabel new];
    self.opacityValueLabel.font = [UIFont monospacedDigitSystemFontOfSize:13 weight:UIFontWeightMedium];
    self.opacityValueLabel.textColor = UIColor.secondaryLabelColor;
    self.opacityValueLabel.textAlignment = NSTextAlignmentRight;
    self.opacityValueLabel.text = [NSString stringWithFormat:@"%d%%", (int)lroundf(self.opacitySlider.value * 100.0f)];
}

- (void)doneTapped {
    if (self.onDone) self.onDone();
}

- (void)styleChanged:(UISegmentedControl *)sender {
    FMSetNumberPref(@"orbHandleStyle", @(sender.selectedSegmentIndex));
    if (self.onChange) self.onChange();
}

- (void)appearanceChanged:(UISegmentedControl *)sender {
    FMSetNumberPref(@"appearanceMode", @(sender.selectedSegmentIndex));
    if (self.onChange) self.onChange();
}

- (void)scaleChanged:(UISlider *)sender {
    self.scaleValueLabel.text = [NSString stringWithFormat:@"%.2fx", sender.value];
    FMSetNumberPref(@"orbScale", @(sender.value));
    if (self.onChange) self.onChange();
}

- (void)opacityChanged:(UISlider *)sender {
    self.opacityValueLabel.text = [NSString stringWithFormat:@"%d%%", (int)lroundf(sender.value * 100.0f)];
    FMSetNumberPref(@"orbOpacity", @(sender.value));
    if (self.onChange) self.onChange();
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    (void)tableView;
    return 2;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    (void)tableView;
    return section == 0 ? 2 : 2;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    (void)tableView;
    return section == 0 ? @"外观样式" : @"大小与透明度";
}

- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section {
    (void)tableView;
    if (section == 1) {
        return @"仅保留拖动吸边与点击返回 LiveContainer 功能，不触碰音频会话与画中画。";
    }
    return nil;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    (void)tableView;
    UITableViewCell *cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:nil];
    cell.selectionStyle = UITableViewCellSelectionStyleNone;

    if (indexPath.section == 0) {
        UILabel *title = [UILabel new];
        title.font = [UIFont systemFontOfSize:15 weight:UIFontWeightRegular];
        title.text = indexPath.row == 0 ? @"形状样式" : @"主题配色";
        UISegmentedControl *seg = indexPath.row == 0 ? self.styleControl : self.appearanceControl;

        UIStackView *stack = [[UIStackView alloc] initWithArrangedSubviews:@[title, seg]];
        stack.axis = UILayoutConstraintAxisVertical;
        stack.spacing = 10;
        stack.translatesAutoresizingMaskIntoConstraints = NO;
        [cell.contentView addSubview:stack];
        [NSLayoutConstraint activateConstraints:@[
            [stack.topAnchor constraintEqualToAnchor:cell.contentView.topAnchor constant:12],
            [stack.bottomAnchor constraintEqualToAnchor:cell.contentView.bottomAnchor constant:-12],
            [stack.leadingAnchor constraintEqualToAnchor:cell.contentView.leadingAnchor constant:16],
            [stack.trailingAnchor constraintEqualToAnchor:cell.contentView.trailingAnchor constant:-16],
        ]];
        return cell;
    }

    UILabel *title = [UILabel new];
    title.font = [UIFont systemFontOfSize:15 weight:UIFontWeightRegular];
    title.text = indexPath.row == 0 ? @"按钮大小" : @"透明度";
    UILabel *valLabel = indexPath.row == 0 ? self.scaleValueLabel : self.opacityValueLabel;
    UISlider *slider = indexPath.row == 0 ? self.scaleSlider : self.opacitySlider;

    UIStackView *header = [[UIStackView alloc] initWithArrangedSubviews:@[title, valLabel]];
    header.axis = UILayoutConstraintAxisHorizontal;
    header.distribution = UIStackViewDistributionEqualSpacing;

    UIStackView *stack = [[UIStackView alloc] initWithArrangedSubviews:@[header, slider]];
    stack.axis = UILayoutConstraintAxisVertical;
    stack.spacing = 8;
    stack.translatesAutoresizingMaskIntoConstraints = NO;
    [cell.contentView addSubview:stack];
    [NSLayoutConstraint activateConstraints:@[
        [stack.topAnchor constraintEqualToAnchor:cell.contentView.topAnchor constant:12],
        [stack.bottomAnchor constraintEqualToAnchor:cell.contentView.bottomAnchor constant:-12],
        [stack.leadingAnchor constraintEqualToAnchor:cell.contentView.leadingAnchor constant:16],
        [stack.trailingAnchor constraintEqualToAnchor:cell.contentView.trailingAnchor constant:-16],
    ]];
    return cell;
}

@end

#pragma mark - Manager Implementation

@implementation FMReturnManager

+ (instancetype)shared {
    static FMReturnManager *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [FMReturnManager new];
    });
    return instance;
}

- (void)installIfPossible {
    if (!NSThread.isMainThread) {
        dispatch_async(dispatch_get_main_queue(), ^{ [self installIfPossible]; });
        return;
    }
    if (!self.orbitContext) return;

    UIWindowScene *scene = [LCOrbitHost activeScene];
    if (!scene) return;

    UIView *container = [self.orbitContext.overlays mountModule:@"FloatingMenu" inScene:scene];
    if (!container) return;

    self.window = self.orbitContext.overlays.window;
    if (!self.hostView || self.hostView.superview != container) {
        [self.hostView removeFromSuperview];
        FMOverlayHostView *host = [[FMOverlayHostView alloc] initWithFrame:container.bounds];
        host.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        host.backgroundColor = UIColor.clearColor;
        __weak typeof(self) weakSelf = self;
        host.onLayout = ^{
            if (!weakSelf.isDragging) [weakSelf layoutOrbAnimated:NO];
        };
        [container addSubview:host];
        self.hostView = host;
        self.orbView = nil;
    }

    [self ensureOrbView];
    [self refreshUI];
}

- (void)ensureOrbView {
    if (self.orbView && self.orbView.superview == self.hostView) return;

    UIView *orb = [UIView new];
    orb.clipsToBounds = YES;
    orb.userInteractionEnabled = YES;

    UIVisualEffectView *blur = [[UIVisualEffectView alloc] initWithEffect:[UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemChromeMaterial]];
    blur.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    blur.userInteractionEnabled = NO;
    [orb addSubview:blur];

    UIImageView *icon = [UIImageView new];
    icon.contentMode = UIViewContentModeCenter;
    icon.userInteractionEnabled = NO;
    [orb addSubview:icon];

    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleTap:)];
    UIPanGestureRecognizer *pan = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handlePan:)];
    [tap requireGestureRecognizerToFail:pan];
    [orb addGestureRecognizer:tap];
    [orb addGestureRecognizer:pan];

    [self.hostView addSubview:orb];
    self.orbView = orb;
    self.blurView = blur;
    self.iconView = icon;
}

- (BOOL)shouldShowOrb {
    if (self.settingsWindow) return NO;
    if ([LCOrbitHost isHostUI]) {
        return [LCOrbitMultitask shouldShowFloatingMenu];
    }
    return YES;
}

- (void)refreshUI {
    if (!NSThread.isMainThread) {
        dispatch_async(dispatch_get_main_queue(), ^{ [self refreshUI]; });
        return;
    }
    if (!self.orbitContext || !self.hostView) return;

    BOOL visible = [self shouldShowOrb];
    [self.orbitContext.overlays setModule:@"FloatingMenu" visible:visible];
    [self.orbitContext.overlays updateFrame];
    self.orbView.hidden = !visible;
    if (!visible) return;

    [self applyOrbAppearance];
    if (!self.isDragging) {
        [self layoutOrbAnimated:NO];
    }
}

- (CGSize)orbSizeForStyle:(FMOrbStyle)style scale:(CGFloat)scale {
    switch (style) {
        case FMOrbStyleCapsule:
            return CGSizeMake(round(20.0 * scale), round(64.0 * scale));
        case FMOrbStyleDroplet:
            return CGSizeMake(round(28.0 * scale), round(52.0 * scale));
        case FMOrbStyleCircle:
        default:
            return CGSizeMake(round(44.0 * scale), round(44.0 * scale));
    }
}

- (void)applyOrbAppearance {
    if (!self.orbView) return;

    FMOrbStyle style = FMOrbStylePref();
    CGFloat scale = FMOrbScale();
    FMAppearanceMode mode = FMAppearancePref();
    BOOL rightSide = FMOrbRightSidePref();

    UIBlurEffectStyle blurStyle = UIBlurEffectStyleSystemChromeMaterial;
    UIColor *tint = UIColor.labelColor;
    UIColor *borderColor = [UIColor.labelColor colorWithAlphaComponent:0.18];

    if (mode == FMAppearanceLight) {
        blurStyle = UIBlurEffectStyleSystemMaterialLight;
        tint = [UIColor colorWithWhite:0.12 alpha:0.92];
        borderColor = [UIColor colorWithWhite:0.0 alpha:0.12];
    } else if (mode == FMAppearanceDark) {
        blurStyle = UIBlurEffectStyleSystemMaterialDark;
        tint = [UIColor colorWithWhite:0.96 alpha:0.92];
        borderColor = [UIColor colorWithWhite:1.0 alpha:0.22];
    }

    self.blurView.effect = [UIBlurEffect effectWithStyle:blurStyle];
    self.orbView.alpha = FMOrbOpacityPref();
    self.orbView.layer.borderWidth = 0.75;
    self.orbView.layer.borderColor = borderColor.CGColor;

    CGSize sz = [self orbSizeForStyle:style scale:scale];
    if (style == FMOrbStyleCircle) {
        self.orbView.layer.cornerRadius = sz.width * 0.5;
        self.orbView.layer.maskedCorners = kCALayerMinXMinYCorner | kCALayerMaxXMinYCorner |
                                           kCALayerMinXMaxYCorner | kCALayerMaxXMaxYCorner;
    } else if (style == FMOrbStyleDroplet) {
        self.orbView.layer.cornerRadius = sz.width * 0.65;
        self.orbView.layer.maskedCorners = rightSide
            ? (kCALayerMinXMinYCorner | kCALayerMinXMaxYCorner)
            : (kCALayerMaxXMinYCorner | kCALayerMaxXMaxYCorner);
    } else {
        self.orbView.layer.cornerRadius = sz.width * 0.5;
        self.orbView.layer.maskedCorners = kCALayerMinXMinYCorner | kCALayerMaxXMinYCorner |
                                           kCALayerMinXMaxYCorner | kCALayerMaxXMaxYCorner;
    }

    CGFloat symbolPt = FMClamp((style == FMOrbStyleCircle ? 18.0 : 13.0) * scale, 10.0, 26.0);
    UIImageSymbolConfiguration *cfg = [UIImageSymbolConfiguration configurationWithPointSize:symbolPt
                                                                                      weight:UIImageSymbolWeightSemibold];
    NSString *symbolName = (style == FMOrbStyleCircle) ? @"house.fill" : (rightSide ? @"chevron.left" : @"chevron.right");
    self.iconView.image = [UIImage systemImageNamed:symbolName withConfiguration:cfg];
    self.iconView.tintColor = tint;
}

- (void)layoutOrbAnimated:(BOOL)animated {
    if (!self.orbView || !self.hostView) return;
    CGRect bounds = self.hostView.bounds;
    if (bounds.size.width <= 0 || bounds.size.height <= 0) return;

    FMOrbStyle style = FMOrbStylePref();
    CGFloat scale = FMOrbScale();
    CGSize sz = [self orbSizeForStyle:style scale:scale];
    BOOL rightSide = FMOrbRightSidePref();
    UIEdgeInsets safe = self.hostView.safeAreaInsets;

    CGFloat margin = (style == FMOrbStyleDroplet) ? 0.0 : (style == FMOrbStyleCapsule ? 4.0 : 8.0);
    CGFloat x = rightSide ? (bounds.size.width - sz.width - margin) : margin;

    CGFloat minY = safe.top + 12.0;
    CGFloat maxY = MAX(minY, bounds.size.height - safe.bottom - sz.height - 12.0);
    CGFloat y = FMClamp(bounds.size.height * FMOrbYRatioPref() - sz.height * 0.5, minY, maxY);

    CGRect target = CGRectMake(x, y, sz.width, sz.height);
    void (^applyFrame)(void) = ^{
        self.orbView.frame = target;
        self.blurView.frame = self.orbView.bounds;
        self.iconView.frame = self.orbView.bounds;
    };

    if (animated) {
        [UIView animateWithDuration:0.28
                              delay:0
             usingSpringWithDamping:0.82
              initialSpringVelocity:0.3
                            options:UIViewAnimationOptionAllowUserInteraction
                         animations:applyFrame
                         completion:nil];
    } else {
        applyFrame();
    }
}

#pragma mark - Gestures (Drag + Tap to Return Only)

- (void)handlePan:(UIPanGestureRecognizer *)pan {
    if (!self.orbView || !self.hostView) return;
    CGRect bounds = self.hostView.bounds;
    if (bounds.size.width <= 0 || bounds.size.height <= 0) return;

    if (pan.state == UIGestureRecognizerStateBegan) {
        self.isDragging = YES;
    } else if (pan.state == UIGestureRecognizerStateChanged) {
        CGPoint delta = [pan translationInView:self.hostView];
        [pan setTranslation:CGPointZero inView:self.hostView];
        CGPoint c = self.orbView.center;
        CGFloat halfW = self.orbView.bounds.size.width * 0.5;
        CGFloat halfH = self.orbView.bounds.size.height * 0.5;
        UIEdgeInsets safe = self.hostView.safeAreaInsets;
        c.x = FMClamp(c.x + delta.x, halfW, bounds.size.width - halfW);
        c.y = FMClamp(c.y + delta.y, safe.top + halfH, bounds.size.height - safe.bottom - halfH);
        self.orbView.center = c;
    } else if (pan.state == UIGestureRecognizerStateEnded || pan.state == UIGestureRecognizerStateCancelled) {
        self.isDragging = NO;
        BOOL rightSide = self.orbView.center.x >= bounds.size.width * 0.5;
        CGFloat ratio = FMClamp(self.orbView.center.y / bounds.size.height, 0.08, 0.92);
        FMSetNumberPref(@"orbRightSide", @(rightSide));
        FMSetNumberPref(@"orbYRatio", @(ratio));
        [self applyOrbAppearance];
        [self layoutOrbAnimated:YES];
    }
}

- (void)handleTap:(UITapGestureRecognizer *)tap {
    if (tap.state != UIGestureRecognizerStateEnded) return;
    [self returnToLiveContainer];
}

- (void)returnToLiveContainer {
    // Multitask / Host UI mode: natively return to LiveContainer home without touching PiP or audio.
    if ([LCOrbitHost isHostUI]) {
        [LCOrbitMultitask showHome];
        return;
    }

    // Single-app / Guest mode: clear selected app so LC stays on home screen, then reopen LC.
    NSUserDefaults *hostDefaults = [LCOrbitHost hostDefaults];
    [hostDefaults removeObjectForKey:@"selected"];
    [hostDefaults removeObjectForKey:@"selectedContainer"];
    [hostDefaults synchronize];

    NSURL *url = [NSURL URLWithString:@"livecontainer://open-web-page?url=about://blank"];
    UIApplication *app = UIApplication.sharedApplication;
    if (url && [app respondsToSelector:@selector(openURL:options:completionHandler:)]) {
        [app openURL:url options:@{} completionHandler:^(BOOL success) {
            if (!success) exit(0);
        }];
    } else {
        exit(0);
    }
}

#pragma mark - Settings Window (Invoked from LC Host Settings)

- (void)openSettingsInScene:(UIWindowScene *)scene {
    if (!NSThread.isMainThread) {
        dispatch_async(dispatch_get_main_queue(), ^{ [self openSettingsInScene:scene]; });
        return;
    }
    if (!scene) scene = [LCOrbitHost activeScene];
    if (!scene || self.settingsWindow) return;

    for (UIWindow *candidate in scene.windows) {
        if (candidate.isKeyWindow && candidate != self.window) {
            self.previousKeyWindow = candidate;
            break;
        }
    }

    [self.orbitContext.overlays setModule:@"FloatingMenu" visible:NO];

    FMStyleSettingsViewController *vc = [FMStyleSettingsViewController new];
    __weak typeof(self) weakSelf = self;
    vc.onDone = ^{ [weakSelf closeSettings]; };
    vc.onChange = ^{
        [weakSelf applyOrbAppearance];
        [weakSelf layoutOrbAnimated:NO];
    };

    UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:vc];
    UIWindow *win = [[UIWindow alloc] initWithWindowScene:scene];
    win.frame = scene.coordinateSpace.bounds;
    win.windowLevel = UIWindowLevelNormal + 90;
    win.rootViewController = nav;
    self.settingsWindow = win;
    [win makeKeyAndVisible];
}

- (void)closeSettings {
    UIWindow *old = self.settingsWindow;
    self.settingsWindow = nil;
    old.hidden = YES;
    old.rootViewController = nil;

    UIWindow *prior = self.previousKeyWindow;
    self.previousKeyWindow = nil;
    if (prior && prior != old && !prior.hidden) {
        [prior makeKeyWindow];
    }
    [self refreshUI];
}

- (void)detachFromScene {
    [self closeSettings];
    [self.hostView removeFromSuperview];
    self.hostView = nil;
    self.orbView = nil;
    self.blurView = nil;
    self.iconView = nil;
    self.window = nil;
    [self.orbitContext.overlays unmountModule:@"FloatingMenu"];
}

@end

#pragma mark - LCOrbit Module Registration

@interface LCFloatingMenuModule : NSObject <LCOrbitModule>
@property (nonatomic, strong) id configurationObserver;
@end

@implementation LCFloatingMenuModule

- (NSString *)moduleIdentifier {
    return @"FloatingMenu";
}

- (void)orbitDidStartWithContext:(LCOrbitContext *)context {
    FMReturnManager *manager = [FMReturnManager shared];
    manager.orbitContext = context;

    if ([LCOrbitHost isHostUI]) {
        if ([LCOrbitMultitask isEnabled]) {
            NSError *error = nil;
            if (![LCOrbitMultitask setEnabled:YES error:&error]) {
                [LCOrbitMultitask setEnabled:NO error:nil];
            }
        }
        __weak FMReturnManager *weakManager = manager;
        self.configurationObserver = [NSNotificationCenter.defaultCenter
            addObserverForName:LCOrbitMultitaskConfigurationChangedNotification
                        object:nil
                         queue:NSOperationQueue.mainQueue
                    usingBlock:^(NSNotification *note) {
                        (void)note;
                        [weakManager refreshUI];
                    }];
    }

    [manager installIfPossible];
}

- (void)orbitDidReceiveLifecycleEvent:(NSString *)event scene:(UIWindowScene *)scene {
    FMReturnManager *manager = [FMReturnManager shared];
    if ([event isEqualToString:UISceneDidDisconnectNotification]) {
        if (scene && (scene == manager.window.windowScene || scene == manager.settingsWindow.windowScene)) {
            [manager detachFromScene];
        }
        return;
    }
    if ([event isEqualToString:UIApplicationDidReceiveMemoryWarningNotification] ||
        [event isEqualToString:UIApplicationDidEnterBackgroundNotification] ||
        [event isEqualToString:UIApplicationWillResignActiveNotification] ||
        [event isEqualToString:UISceneWillDeactivateNotification]) {
        return;
    }
    if ([LCOrbitHost isHostUI] &&
        ([event isEqualToString:UIApplicationDidBecomeActiveNotification] ||
         [event isEqualToString:@"orbit.retry"])) {
        [LCOrbitStorage reloadWithError:nil];
        if ([LCOrbitMultitask isEnabled]) {
            [LCOrbitMultitask installHooksWithError:nil];
        }
        [LCOrbitMultitask refreshPresentation];
        [manager refreshUI];
    }
    [manager installIfPossible];
}

- (void)orbitWillStop {
    if (self.configurationObserver) {
        [NSNotificationCenter.defaultCenter removeObserver:self.configurationObserver];
        self.configurationObserver = nil;
    }
    if ([LCOrbitHost isHostUI]) {
        [LCOrbitMultitask refreshPresentation];
        [LCOrbitMultitask forgetWindow:nil];
    }
    FMReturnManager *manager = [FMReturnManager shared];
    [manager detachFromScene];
    manager.orbitContext = nil;
}

@end

void LCFloatingMenuRegisterWithOrbit(LCOrbitCore *core) {
    [core registerModule:[LCFloatingMenuModule new]];
    [LCOrbitHostSettings installWithOpenSettings:^(UIWindowScene *scene) {
        [[FMReturnManager shared] openSettingsInScene:scene];
    }];
}
