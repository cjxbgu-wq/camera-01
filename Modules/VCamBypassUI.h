//
//  VCamBypassUI.h — vcam125 License Bypass 控制面板 (v32 UI 模块)
//  独立模块: 悬浮球 + 菜单面板 + 音量键入口
//  Tweak.xm 零修改, 本模块只调用补丁暴露的 6 个接口
//
#import <Foundation/Foundation.h>

#ifdef __cplusplus
extern "C" {
#endif

// ---- 状态读取 (由 UI-PATCH.diff 在 Tweak.xm 中实现, 本模块只声明) ----
BOOL vcam_bypass_status(int *swizzled, int *cfhooks, int *gate2, int *seckey, int *photoenc);

// ---- 控制 ----
BOOL vcam_bypass_set_replace(BOOL on);          // 画面替换总开关
BOOL vcam_bypass_set_camera_pass(BOOL on);      // 相机真画面 (photoFlag=1 跳过)
BOOL vcam_bypass_set_pattern_color(uint32_t color); // 测试图案颜色 BGRA
void vcam_bypass_retry(void);                   // 重试 swizzle
NSString *vcam_bypass_logs(void);               // 内存日志导出
int  vcam_bypass_get_replace(void);             // 读当前开关
int  vcam_bypass_get_camera_pass(void);

// ---- UI 入口 (ctor 由补丁调用) ----
void vcap_ui_mount(void);                       // 仅 SpringBoard 生效

#ifdef __cplusplus
}
#endif