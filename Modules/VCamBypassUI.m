//
//  VCamBypassUI.m — VCam Pro Bypass UI (v32)
//  仅 SpringBoard 进程加载; 其余进程 no-op
//
#import "VCamBypassUI.h"
#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>
#import <objc/runtime.h>

#define VCB_BG   [UIColor colorWithRed:0.07 green:0.09 blue:0.13 alpha:1.0]
#define VCB_PANEL [UIColor colorWithRed:0.11 green:0.14 blue:0.21 alpha:1.0]
#define VCB_LINE [UIColor colorWithRed:0.23 green:0.28 blue:0.40 alpha:1.0]
#define VCB_GREEN [UIColor colorWithRed:0.40 green:0.73 blue:0.42 alpha:1.0]
#define VCB_AMBER [UIColor colorWithRed:1.00 green:0.72 blue:0.30 alpha:1.0]
#define VCB_RED   [UIColor colorWithRed:0.94 green:0.33 blue:0.31 alpha:1.0]
#define VCB_TXT   [UIColor whiteColor]
#define VCB_GRAY  [UIColor colorWithRed:0.60 green:0.65 blue:0.78 alpha:1.0]
#define VCB_CYAN  [UIColor colorWithRed:0.31 green:0.76 blue:0.97 alpha:1.0]

static NSString *vcStatusLine(void);
static BOOL vcReplaceOn(void);
static BOOL vcCameraPassOn(void);
void vcToggleMenu(void);
void vcHideMenu(void);
void vcHideBall(void);
void vcShowMenu(void);
void vcShowBall(void);
@class VCBall;
@class VCMenuVC;

static VCBall *sBallView  = nil;
static VCMenuVC *sMenuVC  = nil;
static NSTimeInterval sUpT  = 0;
static NSTimeInterval sDnT  = 0;
static BOOL sInstalled      = NO;

static UIColor *vcStateColor(void) {
    int sw = 0, cf = 0, g2 = 0, sk = 0, pe = 0;
    vcam_bypass_status(&sw, &cf, &g2, &sk, &pe);
    if (sw && cf && g2 && sk && pe) return VCB_GREEN;
    if (sw || cf) return VCB_AMBER;
    return VCB_RED;
}

// ============================================================
#pragma mark - 悬浮球
// ============================================================
@interface VCBall : UIView {
    UIView *_dot;
    NSTimer *_timer;
    UIPanGestureRecognizer *_pan;
}
@end

@implementation VCBall
- (instancetype)initWithFrame:(CGRect)f {
    self = [super initWithFrame:f];
    if (self) {
        self.backgroundColor = [UIColor colorWithWhite:0 alpha:0.66];
        self.layer.cornerRadius = f.size.width / 2;
        self.layer.borderColor = [UIColor whiteColor].CGColor;
        self.layer.borderWidth = 1;
        _dot = [[UIView alloc] initWithFrame:CGRectMake(f.size.width/2-9, f.size.height/2-9, 18, 18)];
        _dot.layer.cornerRadius = 9;
        _dot.backgroundColor = vcStateColor();
        [self addSubview:_dot];
        self.userInteractionEnabled = YES;

        _pan = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(onPan:)];
        [self addGestureRecognizer:_pan];
        UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(onTap)];
        [self addGestureRecognizer:tap];

        _timer = [NSTimer timerWithTimeInterval:1.0 target:self selector:@selector(refresh)
                                       userInfo:nil repeats:YES];
        [[NSRunLoop mainRunLoop] addTimer:_timer forMode:NSRunLoopCommonModes];
    }
    return self;
}
- (void)refresh { _dot.backgroundColor = vcStateColor(); }
- (void)onPan:(UIPanGestureRecognizer *)p {
    CGPoint t = [p translationInView:self.superview];
    self.center = CGPointMake(self.center.x + t.x, self.center.y + t.y);
    [p setTranslation:CGPointZero inView:self.superview];
}
- (void)onTap { vcToggleMenu(); }
@end

// ============================================================
#pragma mark - 菜单面板
// ============================================================
static UILabel *vcLabel(CGRect f, NSString *t, UIColor *c, CGFloat size, BOOL bold) {
    UILabel *l = [[UILabel alloc] initWithFrame:f];
    l.text = t; l.textColor = c; l.font = bold ? [UIFont boldSystemFontOfSize:size]
                                                 : [UIFont systemFontOfSize:size];
    return l;
}
static void vcSwitchRow(UIView *host, CGFloat y, NSString *title, BOOL on, id target, SEL sel) {
    UIView *row = [[UIView alloc] initWithFrame:CGRectMake(12, y, 276, 40)];
    row.backgroundColor = [UIColor colorWithWhite:1 alpha:0.06];
    row.layer.cornerRadius = 6;
    [host addSubview:row];
    [row addSubview:vcLabel(CGRectMake(12, 10, 170, 20), title, VCB_TXT, 14, NO)];
    UISwitch *sw = [[UISwitch alloc] initWithFrame:CGRectMake(200, 4, 60, 32)];
    sw.on = on; [sw addTarget:target action:sel forControlEvents:UIControlEventValueChanged];
    [row addSubview:sw];
}
static UIButton *vcActionBtn(UIView *host, CGFloat y, NSString *title, id target, SEL sel) {
    UIButton *b = [UIButton buttonWithType:UIButtonTypeSystem];
    b.frame = CGRectMake(12, y, 276, 34);
    [b setTitle:title forState:UIControlStateNormal];
    [b setTitleColor:VCB_CYAN forState:UIControlStateNormal];
    b.backgroundColor = [UIColor colorWithWhite:1 alpha:0.06];
    b.layer.cornerRadius = 6;
    [b addTarget:target action:sel forControlEvents:UIControlEventTouchUpInside];
    [host addSubview:b];
    return b;
}

@interface VCMenuVC : UIViewController
@end
@implementation VCMenuVC
- (instancetype)init {
    self = [super init];
    if (self) {
        // 对齐参考工程: 用 topVC present 弹窗, 不建独立 UIWindow
        // (iOS 13+ 无 scene 关联的 UIWindow 不渲染 → 悬浮窗不显示)
        self.modalPresentationStyle = UIModalPresentationFormSheet;
        self.preferredContentSize = CGSizeMake(300, 330);
    }
    return self;
}
- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.bounds = CGRectMake(0, 0, 300, 330);
    self.view.backgroundColor = VCB_PANEL;
    self.view.layer.cornerRadius = 16;
    self.view.layer.borderColor = VCB_LINE.CGColor;
    self.view.layer.borderWidth = 1;

    [self.view addSubview:vcLabel(CGRectMake(16, 10, 200, 30), @"VCam Pro Bypass", VCB_TXT, 17, YES)];
    UIView *dot = [[UIView alloc] initWithFrame:CGRectMake(16, 50, 10, 10)];
    dot.layer.cornerRadius = 5; dot.backgroundColor = vcStateColor();
    [self.view addSubview:dot];
    [self.view addSubview:vcLabel(CGRectMake(34, 44, 250, 22), vcStatusLine(), VCB_GRAY, 12, NO)];

    vcSwitchRow(self.view, 72,  @"画面替换",   vcReplaceOn(),     self, @selector(onReplace:));
    vcSwitchRow(self.view, 120, @"相机真画面", vcCameraPassOn(), self, @selector(onCamera:));
    vcActionBtn(self.view, 170, @"重新注入",   self, @selector(onRetry));
    vcActionBtn(self.view, 210, @"导出日志",   self, @selector(onExportLog));
    vcActionBtn(self.view, 250, @"隐藏悬浮球", self, @selector(onHide));
    vcActionBtn(self.view, 290, @"关闭面板",   self, @selector(onClose));
}
- (void)viewWillAppear:(BOOL)a { [super viewWillAppear:a]; [self refreshStatus]; }
- (void)refreshStatus { [[self.view viewWithTag:99] removeFromSuperview];
    UILabel *l = vcLabel(CGRectMake(16, 44, 260, 22), vcStatusLine(), VCB_GRAY, 12, NO);
    l.tag = 99; [self.view addSubview:l]; }
- (void)onReplace:(UISwitch *)s { vcam_bypass_set_replace(s.on); [self refreshStatus]; }
- (void)onCamera:(UISwitch *)s  { vcam_bypass_set_camera_pass(s.on); [self refreshStatus]; }
- (void)onRetry   { vcam_bypass_retry(); [self refreshStatus]; }
- (void)onClose   { vcHideMenu(); }
- (void)onHide    { vcHideBall(); vcHideMenu(); }
- (void)onExportLog {
    NSString *log = vcam_bypass_logs() ?: @"";
    NSString *path = @"/var/jb/var/mobile/Library/vcampro-bypass.log";
    [log writeToFile:path atomically:YES encoding:NSUTF8StringEncoding error:nil];
    UIAlertController *a = [UIAlertController alertControllerWithTitle:@"日志已导出"
        message:path preferredStyle:UIAlertControllerStyleAlert];
    [a addAction:[UIAlertAction actionWithTitle:@"好" style:UIAlertActionStyleDefault handler:nil]];
    [self presentViewController:a animated:YES completion:nil];
}
@end

static NSString *vcStatusLine(void) {
    int sw = 0, cf = 0, g2 = 0, sk = 0, pe = 0;
    vcam_bypass_status(&sw, &cf, &g2, &sk, &pe);
    return [NSString stringWithFormat:@"swizzle:%@ hook:%@ gate2:%@ seckey:%@ photoenc:%@",
        sw ? @"ON" : @"--", cf ? @"ON" : @"--", g2 ? @"ON" : @"--", sk ? @"ON" : @"--", pe ? @"ON" : @"--"];
}

// ============================================================
#pragma mark - 窗口管理 / 音量入口
// ============================================================
static BOOL vcReplaceOn(void)     { return vcam_bypass_get_replace() != 0; }
static BOOL vcCameraPassOn(void)  { return vcam_bypass_get_camera_pass() != 0; }

// 对齐参考工程 vcam_topVC(): 遍历 scenes 找 keyWindow → rootVC → presented 链
static UIViewController *vcTopVC(void) {
    @try {
        UIWindow *w = nil;
        if (@available(iOS 13.0, *)) {
            for (UIScene *s in [UIApplication sharedApplication].connectedScenes) {
                if ([s isKindOfClass:[UIWindowScene class]]) {
                    for (UIWindow *win in ((UIWindowScene *)s).windows) {
                        if (win.isKeyWindow) { w = win; break; }
                    }
                    if (w) break;
                }
            }
        }
        if (!w) w = [UIApplication sharedApplication].windows.firstObject;
        if (!w) return nil;
        UIViewController *vc = w.rootViewController;
        while (vc.presentedViewController) vc = vc.presentedViewController;
        return vc;
    } @catch (NSException *e) { return nil; }
}

void vcShowBall(void) {
    @try {
        if (sBallView) { sBallView.hidden = NO; return; }
        UIViewController *top = vcTopVC();
        if (!top) { NSLog(@"[vcbUI] showBall: no topVC"); return; }
        VCBall *b = [[VCBall alloc] initWithFrame:CGRectMake(0, 0, 64, 64)];
        b.center = CGPointMake(top.view.bounds.size.width - 50,
                               top.view.bounds.size.height * 0.35);
        b.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin |
                             UIViewAutoresizingFlexibleTopMargin;
        [top.view addSubview:b];
        sBallView = b;
        NSLog(@"[vcbUI] ball shown on topVC.view");
    } @catch (NSException *e) { NSLog(@"[vcbUI] showBall fail: %@", e); }
}

void vcShowMenu(void) {
    @try {
        UIViewController *top = vcTopVC();
        if (!top) { NSLog(@"[vcbUI] showMenu: no topVC"); return; }
        if (top.presentedViewController) {
            NSLog(@"[vcbUI] showMenu: already presenting");
            return;
        }
        if (sMenuVC) {
            [top presentViewController:sMenuVC animated:YES completion:nil];
            return;
        }
        VCMenuVC *vc = [VCMenuVC new];
        sMenuVC = vc;
        [top presentViewController:vc animated:YES completion:nil];
        NSLog(@"[vcbUI] menu presented on topVC");
    } @catch (NSException *e) { NSLog(@"[vcbUI] showMenu fail: %@", e); }
}
void vcHideMenu(void) {
    @try {
        if (!sMenuVC) return;
        UIViewController *p = sMenuVC.presentingViewController;
        [sMenuVC dismissViewControllerAnimated:YES completion:^{ sMenuVC = nil; }];
        if (!p) sMenuVC = nil;
    } @catch (NSException *e) {}
}
void vcHideBall(void) {
    @try {
        [sBallView removeFromSuperview];
        sBallView = nil;
    } @catch (NSException *e) {}
}
void vcToggleMenu(void) {
    if (sMenuVC && sMenuVC.presentingViewController) { vcHideMenu(); } else { vcShowMenu(); }
}

// 音量键入口: 对齐本地参考工程(朋友版 UI 源码)的写法.
// 原实现直接强转调用 (F)method_getImplementation(m) —— runtime 返回的 IMP
// 已带 ptrauth 签名, 在 arm64e (iPhone XS+) 安全;
// 不要用 method_invoke: 它在 arm64e 上对 IMP 签名处理不当会崩 SpringBoard
// (症状: 按音量键屏幕黑屏/锁屏).
static void vcVolumeInstall(void) {
    @try {
        Class cls = NSClassFromString(@"SBVolumeControl");
        NSLog(@"[vcbUI] SBVolumeControl class: %@",
              cls ? NSStringFromClass(cls) : @"(nil)");
        if (!cls) return;
        Method up = class_getInstanceMethod(cls, @selector(increaseVolume));
        Method dn = class_getInstanceMethod(cls, @selector(decreaseVolume));
        NSLog(@"[vcbUI] up=%s dn=%s",
              up ? method_getTypeEncoding(up) : "(nil)",
              dn ? method_getTypeEncoding(dn) : "(nil)");
        if (!up || !dn) { NSLog(@"[vcbUI] volume methods missing, skip"); return; }
        typedef void (*vcVolFn)(id, SEL);
        vcVolFn origUp = (vcVolFn)method_getImplementation(up);
        vcVolFn origDn = (vcVolFn)method_getImplementation(dn);
        SEL selUp = @selector(increaseVolume);
        SEL selDn = @selector(decreaseVolume);
        method_setImplementation(up, imp_implementationWithBlock(^(id self) {
            @try { if (origUp) origUp(self, selUp); }
            @catch (NSException *e) { NSLog(@"[vcbUI] up orig fail: %@", e); }
            NSTimeInterval now = CACurrentMediaTime();
            if (sDnT > 0 && (now - sDnT) < 1.5) { sUpT = sDnT = 0;
                dispatch_async(dispatch_get_main_queue(), ^{ vcShowBall(); }); }
            else sUpT = now;
        }));
        method_setImplementation(dn, imp_implementationWithBlock(^(id self) {
            @try { if (origDn) origDn(self, selDn); }
            @catch (NSException *e) { NSLog(@"[vcbUI] dn orig fail: %@", e); }
            NSTimeInterval now = CACurrentMediaTime();
            if (sUpT > 0 && (now - sUpT) < 1.5) { sUpT = sDnT = 0;
                dispatch_async(dispatch_get_main_queue(), ^{ vcToggleMenu(); }); }
            else sDnT = now;
        }));
        NSLog(@"[vcbUI] volume hooks installed (direct IMP, ref-style)");
    } @catch (NSException *e) {
        NSLog(@"[vcbUI] volume install fail: %@", e);
    }
}

void vcap_ui_mount(void) {
    @try {
        if (sInstalled) return;
        sInstalled = YES;
        NSString *proc = [[NSProcessInfo processInfo] processName];
        if (![proc isEqualToString:@"SpringBoard"]) return; // mediaserverd: no-op
        // 延迟到主线程 + SpringBoard 启动稳定后, 避开 ctor 早期注入时序
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 2 * NSEC_PER_SEC),
                       dispatch_get_main_queue(), ^{
            @try { vcVolumeInstall(); } @catch (NSException *e) {
                NSLog(@"[vcbUI] volume install delayed fail: %@", e);
            }
            NSLog(@"[vcbUI] volume entry installed in SpringBoard");
        });
    } @catch (NSException *e) {
        NSLog(@"[vcbUI] mount fail: %@", e);
    }
}