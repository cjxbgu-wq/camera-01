# CHANGELOG

## v1.0.1-v32 (2026-08-11)

### 新增
- feat: UI 控制面板补丁 (UI-PATCH.diff) + 独立模块 Modules/VCamBypassUI.h/.m:
  悬浮球(三态颜色/拖拽/双击) + 菜单面板 + 音量键入口(SBVolumeControl)。
- feat: Tweak.xm 增量接口补丁(68 行,+64/-4,仅新增标志与接口函数,零删除零重构):
  gReplaceEnabled / gCameraPassEnabled / gPatternColor / gHookGate2/SecKey/PhotoEnc /
  环形日志 vcam_log2 / vcam_bypass_status/set_*/retry/logs 接口。
- UI 功能键与源码一一对应: 替换开关->v23_doReplace 总闸, 相机真画面->photoFlag=1
  分支, 图案颜色->v23_getTestPattern 参数化, 重新注入->tryObjCSwizzle(100),
  导出日志->gLogBuf 环形缓冲, 状态三色->hook 成功标志聚合。

### 说明
- 源码 Tweak.xm 保持原样入库, 应用补丁方式: patch -p1 < UI-PATCH.diff
- 回滚: git checkout -- Tweak.xm Makefile 即完全还原

## v1.0.0-v31 (2026-08-11)

### 新增
- vcam125 运行时授权绕过（v31）：dyld add_image 监听 vcameracrack 加载，
  三层 hook（ObjC swizzle / C 函数 / 全局变量强制写入）+ 100ms ivar enforcer。
- 画面替换：3rd party/网页显示红色测试图案，Apple Camera 显示真画面（防黑屏）。

### 修复
- fix: build.yml 移入 .github/workflows/ 并修正 YAML 顶层缩进，
  GitHub Actions 此前不识别根目录 workflow，push 无法触发构建。
- fix: CI 增加 Theos/SDK 下载重试与 SDK 目录创建，避免网络抖动导致构建失败。

### 说明
- 源码 Tweak.xm 零修改，全部改动以补丁方式交付（如有）。
- Git 提交：fix: 修复 GitHub Actions 构建 workflow 不被识别的问题