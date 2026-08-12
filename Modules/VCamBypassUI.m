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
// 图案颜色预设 (BGRA, 与 Tweak.xm gPatternColor 一致)
static uint32_t vcColorTable[] = {
    0xFFFF0000, 0xFF00FF00, 0xFF0000FF,
    0xFFFFFF00, 0xFF00FFFF, 0xFFFFFFFF
};
static const char *vcColorNames[] = {"RED", "GREEN", "BLUE", "YELLOW", "CYAN", "WHITE"};
static UIColor *vcBgraToUI(uint32_t c) {
    return [UIColor colorWithRed:((c >> 8) & 0xFF) / 255.0
                           green:((c >> 16) & 0xFF) / 255.0
                            blue:(c & 0xFF) / 255.0
                           alpha:1.0];
}

@interface VCMenuVC : UIViewController <UIScrollViewDelegate> {
    UIScrollView *_pages;
    UIButton *_tab1, *_tab2, *_tab3, *_tab4;
    UIView *_colorDot;
    UIView *_barFill;
    UISwitch *_swReplace, *_swCamera;
    UILabel *_chipVal[4];
    UILabel *_stVal[5];
}
@end
@implementation VCMenuVC
- (instancetype)init {
    self = [super init];
    if (self) {
        // 对齐参考工程: 用 topVC present 弹窗, 不建独立 UIWindow
        // (iOS 13+ 无 scene 关联的 UIWindow 不渲染 → 悬浮窗不显示)
        self.modalPresentationStyle = UIModalPresentationFormSheet;
        self.preferredContentSize = CGSizeMake(350, 544);
    }
    return self;
}

// ---- 组件工厂 (参考工程构图: 深色能量卡片) ----
- (UILabel *)mkChip:(UIView *)host x:(CGFloat)x y:(CGFloat)y w:(CGFloat)w label:(NSString *)l val:(NSString *)v color:(UIColor *)c {
    UIView *box = [[UIView alloc] initWithFrame:CGRectMake(x, y, w, 26)];
    box.backgroundColor = [UIColor colorWithWhite:1 alpha:0.05];
    box.layer.cornerRadius = 8;
    box.layer.borderWidth = 1;
    box.layer.borderColor = VCB_LINE.CGColor;
    UILabel *lab = [[UILabel alloc] initWithFrame:CGRectMake(7, 2, w - 14, 9)];
    lab.text = l;
    lab.font = [UIFont systemFontOfSize:7];
    lab.textColor = VCB_GRAY;
    [box addSubview:lab];
    UILabel *valL = [[UILabel alloc] initWithFrame:CGRectMake(7, 11, w - 14, 12)];
    valL.text = v;
    valL.font = [UIFont boldSystemFontOfSize:8.5];
    valL.textColor = c;
    valL.textAlignment = NSTextAlignmentRight;
    [box addSubview:valL];
    [host addSubview:box];
    return valL;
}
- (UIButton *)mkTab:(NSString *)t x:(CGFloat)x sel:(BOOL)s tag:(NSInteger)tag {
    UIButton *b = [UIButton buttonWithType:UIButtonTypeCustom];
    b.frame = CGRectMake(x, 42, 56, 22);
    b.tag = tag;
    b.layer.cornerRadius = 11;
    b.backgroundColor = s ? VCB_CYAN : [UIColor colorWithWhite:1 alpha:0.08];
    [b setTitle:t forState:UIControlStateNormal];
    b.titleLabel.font = [UIFont boldSystemFontOfSize:10];
    [b setTitleColor:s ? VCB_BG : VCB_GRAY forState:UIControlStateNormal];
    [b addTarget:self action:@selector(switchPage:) forControlEvents:UIControlEventTouchUpInside];
    return b;
}
- (UIButton *)mkBtn:(NSString *)t x:(CGFloat)x y:(CGFloat)y w:(CGFloat)w h:(CGFloat)h font:(CGFloat)fs color:(UIColor *)c tag:(NSInteger)tag {
    UIButton *b = [UIButton buttonWithType:UIButtonTypeCustom];
    b.frame = CGRectMake(x, y, w, h);
    b.tag = tag;
    b.layer.cornerRadius = 8;
    b.backgroundColor = c;
    [b setTitle:t forState:UIControlStateNormal];
    [b setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    b.titleLabel.font = [UIFont boldSystemFontOfSize:fs];
    [b addTarget:self action:@selector(btnTap:) forControlEvents:UIControlEventTouchUpInside];
    return b;
}
- (UIView *)mkSwitchRow:(UIView *)host x:(CGFloat)x y:(CGFloat)y w:(CGFloat)w title:(NSString *)t sw:(UISwitch **)outSw {
    UIView *row = [[UIView alloc] initWithFrame:CGRectMake(x, y, w, 44)];
    row.backgroundColor = [UIColor colorWithWhite:1 alpha:0.06];
    row.layer.cornerRadius = 8;
    [host addSubview:row];
    UILabel *l = [[UILabel alloc] initWithFrame:CGRectMake(10, 12, w - 70, 20)];
    l.text = t;
    l.font = [UIFont boldSystemFontOfSize:11];
    l.textColor = VCB_TXT;
    [row addSubview:l];
    UISwitch *sw = [[UISwitch alloc] initWithFrame:CGRectMake(w - 62, 6, 52, 32)];
    [row addSubview:sw];
    if (outSw) *outSw = sw;
    return row;
}
- (void)mkStatusRow:(UIView *)host y:(CGFloat)y label:(NSString *)l tag:(int)tag {
    UILabel *lab = [[UILabel alloc] initWithFrame:CGRectMake(20, y, 200, 14)];
    lab.text = l;
    lab.font = [UIFont systemFontOfSize:10];
    lab.textColor = VCB_GRAY;
    [host addSubview:lab];
    UILabel *val = [[UILabel alloc] initWithFrame:CGRectMake(180, y, 96, 14)];
    val.font = [UIFont boldSystemFontOfSize:10];
    val.textAlignment = NSTextAlignmentRight;
    val.tag = tag;
    [host addSubview:val];
    _stVal[tag - 1] = val;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor clearColor];
    self.view.bounds = CGRectMake(0, 0, 350, 544);
    CGFloat cw = 350;

    UIView *card = [[UIView alloc] initWithFrame:self.view.bounds];
    card.layer.cornerRadius = 20;
    card.clipsToBounds = YES;
    card.backgroundColor = VCB_PANEL;
    [self.view addSubview:card];

    CAGradientLayer *edge = [CAGradientLayer layer];
    edge.frame = CGRectMake(0, 0, cw, 2.5);
    edge.colors = @[(id)VCB_CYAN.CGColor, (id)[UIColor colorWithRed:0.91 green:0.47 blue:0.98 alpha:1.0].CGColor];
    [card.layer addSublayer:edge];

    UILabel *title = [[UILabel alloc] initWithFrame:CGRectMake(18, 24, cw - 120, 20)];
    title.text = @"VCam Pro Bypass";
    title.font = [UIFont boldSystemFontOfSize:15];
    title.textColor = [UIColor whiteColor];
    [card addSubview:title];
    UILabel *sub = [[UILabel alloc] initWithFrame:CGRectMake(18, 39, cw - 120, 9)];
    sub.text = @"ENERGY DECK · VIRTUAL CAMERA · OFFLINE";
    sub.font = [UIFont systemFontOfSize:7];
    sub.textColor = VCB_GRAY;
    [card addSubview:sub];

    _colorDot = [[UIView alloc] initWithFrame:CGRectMake(cw - 36, 14, 26, 26)];
    _colorDot.layer.cornerRadius = 13;
    _colorDot.layer.borderWidth = 2;
    _colorDot.layer.borderColor = [UIColor whiteColor].CGColor;
    _colorDot.backgroundColor = vcBgraToUI(0xFFFF0000);
    [card addSubview:_colorDot];

    UIView *sep = [[UIView alloc] initWithFrame:CGRectMake(0, 48, cw, 0.5)];
    sep.backgroundColor = VCB_LINE;
    [card addSubview:sep];

    // 双页: FUNC / STATUS
    _tab1 = [self mkTab:@"FUNC" x:20 sel:YES tag:1];
    _tab2 = [self mkTab:@"STATUS" x:84 sel:NO tag:2];
    _tab3 = [self mkTab:@"FUNC" x:20 sel:NO tag:1];
    _tab4 = [self mkTab:@"STATUS" x:84 sel:YES tag:2];
    [card addSubview:_tab1];
    [card addSubview:_tab2];
    [card addSubview:_tab3];
    [card addSubview:_tab4];

    _pages = [[UIScrollView alloc] initWithFrame:CGRectMake(0, 54, cw, 424)];
    _pages.pagingEnabled = YES;
    _pages.showsHorizontalScrollIndicator = NO;
    _pages.bounces = NO;
    _pages.delegate = self;
    _pages.contentSize = CGSizeMake(cw * 2, 424);
    [card addSubview:_pages];

    UIView *pg1 = [[UIView alloc] initWithFrame:CGRectMake(0, 0, cw, 424)];
    UIView *pg2 = [[UIView alloc] initWithFrame:CGRectMake(cw, 0, cw, 424)];
    [_pages addSubview:pg1];
    [_pages addSubview:pg2];

    CGFloat mw = (cw - 40 - 30) / 4;
    _chipVal[0] = [self mkChip:pg1 x:20 y:12 w:mw label:@"REPLACE" val:@"ON" color:VCB_GREEN];
    _chipVal[1] = [self mkChip:pg1 x:20 + (mw + 10) y:12 w:mw label:@"CAMERA" val:@"ON" color:VCB_GREEN];
    _chipVal[2] = [self mkChip:pg1 x:20 + (mw + 10) * 2 y:12 w:mw label:@"HOOKS" val:@"--" color:VCB_AMBER];
    _chipVal[3] = [self mkChip:pg1 x:20 + (mw + 10) * 3 y:12 w:mw label:@"PATTERN" val:@"RED" color:VCB_CYAN];

    CGFloat bw = (cw - 40 - 10) / 2;
    CGFloat lx = 20, rx = 20 + bw + 10;
    // ---- 页1 FUNC ----
    UILabel *sT = [[UILabel alloc] initWithFrame:CGRectMake(lx, 68, bw, 10)];
    sT.text = @"SOURCES";
    sT.font = [UIFont boldSystemFontOfSize:9];
    sT.textColor = VCB_GRAY;
    [pg1 addSubview:sT];
    UILabel *cT = [[UILabel alloc] initWithFrame:CGRectMake(rx, 68, bw, 10)];
    cT.text = @"COLOR FX";
    cT.font = [UIFont boldSystemFontOfSize:9];
    cT.textColor = VCB_GRAY;
    [pg1 addSubview:cT];

    UISwitch *swR = nil, *swC = nil;
    [self mkSwitchRow:pg1 x:lx y:80 w:bw title:@"画面替换" sw:&swR];
    _swReplace = swR;
    _swReplace.on = vcReplaceOn();
    [_swReplace addTarget:self action:@selector(onReplace:) forControlEvents:UIControlEventValueChanged];
    [self mkSwitchRow:pg1 x:lx y:132 w:bw title:@"相机真画面" sw:&swC];
    _swCamera = swC;
    _swCamera.on = vcCameraPassOn();
    [_swCamera addTarget:self action:@selector(onCamera:) forControlEvents:UIControlEventValueChanged];

    for (int i = 0; i < 6; i++) {
        UIButton *cb = [UIButton buttonWithType:UIButtonTypeCustom];
        cb.frame = CGRectMake(rx + (i % 3) * 58, 100 + (i / 3) * 58, 48, 48);
        cb.layer.cornerRadius = 10;
        cb.backgroundColor = vcBgraToUI(vcColorTable[i]);
        cb.layer.borderWidth = 1.5;
        cb.layer.borderColor = [UIColor whiteColor].CGColor;
        cb.tag = i + 1;
        [cb addTarget:self action:@selector(onColor:) forControlEvents:UIControlEventTouchUpInside];
        [pg1 addSubview:cb];
    }

    [pg1 addSubview:[self mkBtn:@"RE-INJECT" x:20 y:216 w:cw - 40 h:44 font:11 color:[UIColor colorWithRed:0.35 green:0.55 blue:0.95 alpha:1] tag:1]];
    [pg1 addSubview:[self mkBtn:@"EXPORT LOG" x:20 y:268 w:cw - 40 h:44 font:11 color:[UIColor colorWithRed:0.45 green:0.62 blue:0.55 alpha:1] tag:2]];

    // ---- 页2 STATUS ----
    CGFloat barX = cw - 20 - 44;
    UILabel *enL = [[UILabel alloc] initWithFrame:CGRectMake(barX, 56, 44, 10)];
    enL.text = @"ENERGY";
    enL.font = [UIFont systemFontOfSize:7.5];
    enL.textColor = VCB_GRAY;
    enL.textAlignment = NSTextAlignmentCenter;
    [pg2 addSubview:enL];
    UIView *barOut = [[UIView alloc] initWithFrame:CGRectMake(barX, 78, 44, 224)];
    barOut.layer.cornerRadius = 22;
    barOut.layer.borderWidth = 3;
    barOut.layer.borderColor = VCB_LINE.CGColor;
    [pg2 addSubview:barOut];
    UIView *barIn = [[UIView alloc] initWithFrame:CGRectMake(barX + 6, 84, 32, 212)];
    barIn.backgroundColor = VCB_BG;
    barIn.layer.cornerRadius = 16;
    [pg2 addSubview:barIn];
    _barFill = [[UIView alloc] initWithFrame:CGRectMake(barX + 6, 84 + 212, 32, 0)];
    _barFill.backgroundColor = VCB_CYAN;
    _barFill.layer.cornerRadius = 16;
    _barFill.alpha = 0.9;
    [pg2 addSubview:_barFill];

    [self mkStatusRow:pg2 y:84  label:@"OBJC SWIZZLE" tag:1];
    [self mkStatusRow:pg2 y:120 label:@"C FUNCTION HOOK" tag:2];
    [self mkStatusRow:pg2 y:156 label:@"GATE2 (license)" tag:3];
    [self mkStatusRow:pg2 y:192 label:@"SECKEY VERIFY" tag:4];
    [self mkStatusRow:pg2 y:228 label:@"PHOTO ENCODER" tag:5];

    // 卡片级关闭按钮 (参考工程同款)
    [card addSubview:[self mkBtn:@"✕ CLOSE PANEL" x:20 y:480 w:cw - 40 h:42 font:13 color:[UIColor colorWithRed:0.9 green:0.33 blue:0.31 alpha:1] tag:9]];
    UILabel *hint = [[UILabel alloc] initWithFrame:CGRectMake(0, 530, cw, 10)];
    hint.text = @"◁▷ swipe pages · tap ball to open";
    hint.font = [UIFont systemFontOfSize:8];
    hint.textColor = VCB_GRAY;
    hint.textAlignment = NSTextAlignmentCenter;
    [card addSubview:hint];
}

- (void)viewWillAppear:(BOOL)a {
    [super viewWillAppear:a];
    [self refreshStatus];
}
- (void)refreshStatus {
    int sw = 0, cf = 0, g2 = 0, sk = 0, pe = 0;
    vcam_bypass_status(&sw, &cf, &g2, &sk, &pe);
    _chipVal[0].text = vcReplaceOn() ? @"ON" : @"OFF";
    _chipVal[0].textColor = vcReplaceOn() ? VCB_GREEN : VCB_RED;
    _chipVal[1].text = vcCameraPassOn() ? @"ON" : @"OFF";
    _chipVal[1].textColor = vcCameraPassOn() ? VCB_GREEN : VCB_RED;
    int hooks = (sw ? 1 : 0) + (cf ? 1 : 0) + (g2 ? 1 : 0) + (sk ? 1 : 0) + (pe ? 1 : 0);
    _chipVal[2].text = [NSString stringWithFormat:@"%d/5", hooks];
    _chipVal[2].textColor = hooks == 5 ? VCB_GREEN : VCB_AMBER;
    _swReplace.on = vcReplaceOn();
    _swCamera.on = vcCameraPassOn();
    BOOL st[5] = {sw, cf, g2, sk, pe};
    UIColor *good = VCB_GREEN, *bad = VCB_GRAY;
    for (int i = 0; i < 5; i++) {
        _stVal[i].text = st[i] ? @"ON" : @"--";
        _stVal[i].textColor = st[i] ? good : bad;
    }
    [UIView animateWithDuration:0.25 animations:^{
        CGRect f = _barFill.frame;
        f.size.height = 212.0 * hooks / 5.0;
        f.origin.y = 84 + 212 - f.size.height;
        _barFill.frame = f;
    }];
}
- (void)onReplace:(UISwitch *)s { vcam_bypass_set_replace(s.on); [self refreshStatus]; }
- (void)onCamera:(UISwitch *)s  { vcam_bypass_set_camera_pass(s.on); [self refreshStatus]; }
- (void)onColor:(UIButton *)b {
    int i = (int)b.tag - 1;
    vcam_bypass_set_pattern_color(vcColorTable[i]);
    _colorDot.backgroundColor = vcBgraToUI(vcColorTable[i]);
    _chipVal[3].text = [NSString stringWithUTF8String:vcColorNames[i]];
    [self refreshStatus];
}
- (void)btnTap:(UIButton *)b {
    if (b.tag == 1) { [self onRetry]; }
    else if (b.tag == 2) { [self onExportLog]; }
    else if (b.tag == 9) { vcHideMenu(); }
}
- (void)onRetry   { vcam_bypass_retry(); [self refreshStatus]; }
- (void)onExportLog {
    NSString *log = vcam_bypass_logs() ?: @"";
    NSString *path = @"/var/jb/var/mobile/Library/vcampro-bypass.log";
    [log writeToFile:path atomically:YES encoding:NSUTF8StringEncoding error:nil];
    UIAlertController *a = [UIAlertController alertControllerWithTitle:@"日志已导出"
        message:path preferredStyle:UIAlertControllerStyleAlert];
    [a addAction:[UIAlertAction actionWithTitle:@"好" style:UIAlertActionStyleDefault handler:nil]];
    [self presentViewController:a animated:YES completion:nil];
}
- (void)switchPage:(UIButton *)sender {
    NSInteger pg = sender.tag;
    [_pages setContentOffset:CGPointMake((pg - 1) * _pages.frame.size.width, 0) animated:YES];
    [self updateTabs:pg];
}
- (void)updateTabs:(NSInteger)pg {
    BOOL s1 = (pg == 1), s2 = (pg == 2);
    _tab1.backgroundColor = s1 ? VCB_CYAN : [UIColor colorWithWhite:1 alpha:0.08];
    _tab2.backgroundColor = s2 ? VCB_CYAN : [UIColor colorWithWhite:1 alpha:0.08];
    _tab3.backgroundColor = s1 ? VCB_CYAN : [UIColor colorWithWhite:1 alpha:0.08];
    _tab4.backgroundColor = s2 ? VCB_CYAN : [UIColor colorWithWhite:1 alpha:0.08];
    [_tab1 setTitleColor:s1 ? VCB_BG : VCB_GRAY forState:UIControlStateNormal];
    [_tab2 setTitleColor:s2 ? VCB_BG : VCB_GRAY forState:UIControlStateNormal];
    [_tab3 setTitleColor:s1 ? VCB_BG : VCB_GRAY forState:UIControlStateNormal];
    [_tab4 setTitleColor:s2 ? VCB_BG : VCB_GRAY forState:UIControlStateNormal];
}
- (void)scrollViewDidEndDecelerating:(UIScrollView *)sv {
    NSInteger pg = (NSInteger)(sv.contentOffset.x / MAX(sv.frame.size.width, 1)) + 1;
    [self updateTabs:pg];
}
@end

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