//
//  VCamBypassUI.m — vcam125 License Bypass UI (v32)
//  仅 SpringBoard 进程加载; 其余进程 no-op
//
#import "VCamBypassUI.h"
#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <objc/message.h>

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

static UIWindow *sBallWin   = nil;
static UIWindow *sMenuWin   = nil;
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
- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.frame = CGRectMake(0, 0, 300, 330);
    self.view.backgroundColor = VCB_PANEL;
    self.view.layer.cornerRadius = 16;
    self.view.layer.borderColor = VCB_LINE.CGColor;
    self.view.layer.borderWidth = 1;

    [self.view addSubview:vcLabel(CGRectMake(16, 10, 200, 30), @"vcam125 Bypass", VCB_TXT, 17, YES)];
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
    NSString *path = @"/var/jb/var/mobile/Library/vcam125-bypass.log";
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
void vcToggleMenu(void);
void vcHideMenu(void);
void vcHideBall(void);

void vcShowBall(void) {
    if (sBallWin) { sBallWin.hidden = NO; return; }
    sBallWin = [[UIWindow alloc] initWithFrame:CGRectMake(0, 0, 64, 64)];
    sBallWin.windowLevel = UIWindowLevelStatusBar + 100;
    sBallWin.backgroundColor = [UIColor clearColor];
    sBallWin.rootViewController = [UIViewController new];
    sBallWin.userInteractionEnabled = YES;
    VCBall *b = [[VCBall alloc] initWithFrame:sBallWin.bounds];
    [sBallWin addSubview:b];
    CGFloat w = [UIScreen mainScreen].bounds.size.width;
    CGFloat h = [UIScreen mainScreen].bounds.size.height;
    sBallWin.center = CGPointMake(w - 50, h * 0.35);
    sBallWin.hidden = NO;
}

void vcShowMenu(void) {
    if (sMenuWin) { sMenuWin.hidden = NO; return; }
    sMenuWin = [[UIWindow alloc] initWithFrame:CGRectMake(0, 0, 300, 340)];
    sMenuWin.windowLevel = UIWindowLevelStatusBar + 101;
    sMenuWin.backgroundColor = [UIColor clearColor];
    sMenuWin.rootViewController = [VCMenuVC new];
    sMenuWin.center = [UIScreen mainScreen].center;
    sMenuWin.hidden = NO;
}
void vcHideMenu(void) { if (sMenuWin) sMenuWin.hidden = YES; }
void vcHideBall(void) { if (sBallWin) sBallWin.hidden = YES; }
void vcToggleMenu(void) {
    if (sMenuWin && !sMenuWin.hidden) { vcHideMenu(); } else { vcShowMenu(); }
}

static void vcVolumeInstall(void) {
    Class cls = NSClassFromString(@"SBVolumeControl");
    if (!cls) return;
    Method up = class_getInstanceMethod(cls, @selector(increaseVolume));
    Method dn = class_getInstanceMethod(cls, @selector(decreaseVolume));
    if (!up || !dn) return;
    IMP oup = method_getImplementation(up), odn = method_getImplementation(dn);
    method_setImplementation(up, imp_implementationWithBlock(^(id self) {
        ((void (*)(id, SEL))oup)(self, @selector(increaseVolume));
        NSTimeInterval now = CACurrentMediaTime();
        if (sDnT > 0 && (now - sDnT) < 1.5) { sUpT = sDnT = 0;
            dispatch_async(dispatch_get_main_queue(), ^{ vcShowBall(); }); }
        else sUpT = now;
    }));
    method_setImplementation(dn, imp_implementationWithBlock(^(id self) {
        ((void (*)(id, SEL))odn)(self, @selector(decreaseVolume));
        NSTimeInterval now = CACurrentMediaTime();
        if (sUpT > 0 && (now - sUpT) < 1.5) { sUpT = sDnT = 0;
            dispatch_async(dispatch_get_main_queue(), ^{ vcToggleMenu(); }); }
        else sDnT = now;
    }));
}

void vcap_ui_mount(void) {
    if (sInstalled) return;
    sInstalled = YES;
    NSString *proc = [[NSProcessInfo processInfo] processName];
    if (![proc isEqualToString:@"SpringBoard"]) return; // mediaserverd: no-op
    vcVolumeInstall();
    NSLog(@"[vcbUI] volume entry installed in %@", proc);
}