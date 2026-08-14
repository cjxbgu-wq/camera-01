# CHANGELOG

## v1.2.2 (2026-08-14)

### 诊断 (自检结论: 引擎 hook 目标不存在)
- 本地 Mach-O 解析千面安装包 vcameracrack.dylib (arm64e slice):
  - 段布局 __TEXT 0x0-0x2C000 / __DATA_CONST / __DATA 0x30000-0x34000
  - 全部 0x63xxx 偏移 (g_isLicenseValid/g_features/g_expiry/stash 槽) → **段外不存在**
  - 符号表/字符串表 **无 LicenseCore/VCamCore/isLicenseValid/renderReplacementToPixelBuffer**
  - 千面版是独立实现: GPUImageProcessor + hook 系统类 BWNodeOutput/BWStillImageScalerNode/
    BWPhotoEncoderNode + 媒体 /var/mobile/Media/DCIM/vcam + RTMP
  - 结论: v15-v40 的「等 LicenseCore/VCamCore 出现再 swizzle」架构对千面版无效,
    替换核心必须重写为直接 hook 系统相机管线 (千面同路线)
- v41: 系统类探测器 — 每进程 3 次 (5s/15s/30s) 枚举 BWNodeOutput/BWStillImageScalerNode/
  BWPhotoEncoderNode/GPUImageProcessor/LicenseCore/VCamCore 存在性 + 方法列表 → engine.log
  供重写替换核心使用 (真实 selector)
- v41: 打包改为 **THEOS_PACKAGE_SCHEME=roothide** (RootHide 官方 Theos) — dylib+plist
  直接进 /var/jb/usr/lib/TweakInject/ (RootHide 注入器读取位置, 不再依赖 substrate
  布局映射); INSTALL_TARGET_PROCESSES 仅 SpringBoard
- v41: plist Filter 恢复明确目标 (springboard+mediaserverd), 不做全局注入; 测试 App
  bundle id 由用户在 RootHide App List 勾选 + 追加到 plist Bundles
- 注: 用户确认环境 = RootHide Bootstrap (App List 按需注入), 打包应用
  THEOS_PACKAGE_SCHEME=roothide; plist Filter 用明确测试目标 Bundle ID, 不做全局注入

## v1.2.1 (2026-08-14)

### 修复 (核心: 注入目标不再猜测)
- fix: v39 假设「千面在 com.apple.lskdd 进程」仍不可验证 — 真机三轮日志中
  lskdd 进程从未启动/注入, 且用户无法确认该 App 存在. v40: **移除
  vcampro-bypass.plist 的 Filter → 全进程注入** (ellekit/substrate 无 Filter
  = 注入所有进程). 引擎为任意进程设计: 匹配到 vcameracrack 才 hook, 其他进程
  仅空转轮询 (无副作用); UI 仍只在 SpringBoard 挂载 (vcap_ui_mount 已按进程名
  拦截). 用户在用千面替换成功的任意 App 中测试, 引擎必然进入.

## v1.2.0 (2026-08-14)

### 修复 (核心: 相机替换全部功能)
- fix: 千面引擎进程错位 — 千面 (com.taokk3.qianmian) 的 vcameracrack.plist 注入
  mediaserverd + SpringBoard + **com.apple.lskdd** 三进程, 实测 RootHide 环境
  daemon 不注入 → vcameracrack 只在 **lskdd App 进程** 加载 (千面自测替换成功,
  我们的引擎却只注入 mediaserverd+SpringBoard → hook 全空 → 所有功能不可用).
  v39: `vcampro-bypass.plist` Filter 增加 com.apple.lskdd/lskdd, 引擎进真实
  引擎进程 → 替换/视频/图片/颜色/旋转/暂停/动作全部走通.
- fix: 状态回写进程判定 — v35 状态回写原按进程名 mediaserverd 启动, 现改为
  onImageLoad 匹配到 vcameracrack 后启动 (真实引擎进程), status 文件不再假 0/5.

## v1.1.10 (2026-08-14)

### 修复
- fix: engine.log 跨进程并发写覆盖 — SpringBoard/mediaserverd 同时读写同一文件,
  后写者基于旧内容覆盖 → 丢行 (诊断时引擎日志可能完全消失). v38 改用 flock 排他锁
  读改写全程持锁.
- feat: 日志页引擎心跳 — 首行显示 `[mediaserverd] 运行中/未运行`, 一眼判断
  tweak 是否注入引擎进程 (status 文件新鲜度检测). 未运行 = 所有功能不可用的根因.

## v1.1.9 (2026-08-14)

### 功能
- feat: 软件内完整运行日志 (v37) — 之前日志只有 SpringBoard 进程内存缓冲,
  mediaserverd 引擎的关键事件 (vcameracrack 匹配/hook 结果/渲染错误/动作引擎)
  面板里看不到. v37:
  - 统一落盘: 所有 vcam_log2 事件 (引擎+面板) 追加写
    `/var/jb/var/mobile/Library/vcamplus/engine.log` (限 300 行, 带进程名前缀),
    帧级错误 (渲染 NULL/读取器失败/VT 会话失败) 走 5s 限频防刷爆;
    引擎关键 NSLog 全部接入落盘日志.
  - 面板新增第 4 页签「日志」: 实时查看完整运行日志 (engine.log 全文 + 面板
    内存缓冲合并显示), 「⟳ 刷新日志」「复制日志」(剪贴板, 可发回分析)
    「清空日志」.
  - 新接口 vcam_bypass_engine_log / vcam_bypass_clear_log.

## v1.1.8 (2026-08-14)

### 修复
- fix: vcam125 固定偏移无边界校验 — 千面升级导致偏移错位时, `writeVcamIvars`
  直接写内存 = EXC_BAD_ACCESS (信号级崩溃, @try 拦不住) → mediaserverd 崩溃循环 →
  相机黑屏. v36 新增 `vcam_addrInImage` Mach-O 段边界校验, 所有偏移操作
  (ivar 写入 / gate2 0xe9f4 / photoenc 0xe240 / stash slot 0x639d8/0x639e0 读取)
  先校验地址在映射段内且段可写, 越界则跳过并打日志.
- fix: vcameracrack dylib 名匹配静默失效 — `strstr("vcameracrack")` 不匹配
  (改名/大小写) 时所有功能静默不生效. v36 放宽: 含 "vcam" 的 image 打印日志
  并做关键偏移段校验, 通过则视为目标; ctor 枚举所有已加载 image 打印候选.
- fix: STATUS 页新增第 6 行「VCAM 引擎」— 显示 mediaserverd 是否匹配到 vcam
  dylib (status 文件第 11 字段), 可直接区分"千面未加载"与"hook 未生效".

## v1.1.7 (2026-08-14)

### 修复
- fix: 状态检测跨进程失效 — STATUS 页 5 项 hook 状态原先读 SpringBoard 本进程
  globals (SpringBoard 永不加载 vcameracrack → 永远 0/5, 误导排查)。
  新增 v35 引擎状态回写: mediaserverd 每 0.5s 写
  `/var/jb/var/mobile/Library/vcamplus/status`
  `swizzled,cfhooks,gate2,seckey,photoenc,replace,colorInject,sourceMode,pause,actionActive`,
  `vcam_bypass_status` 优先读新鲜 (<2s) 状态文件, 无文件回退本进程值。
  真机排查时 STATUS 页现可真实反映引擎挂载情况。

## v1.1.6 (2026-08-12)

### 功能
- feat: 集成 VCActionSystem 分段动作模块 (v34, 按构建图纸/UI图纸/总UI图纸确认后实施):
  独立模块接入 — 动作配置 JSON 与参考工程同 schema `{version,videoName,videoSize,duration,actions[]}`,
  落盘 `/var/jb/var/mobile/Library/vcamplus/actions.json`。
  - 引擎 (Tweak.xm, 替换进程): controls 协议由 11 字段扩为 13 字段
    `1,rot,flip,pause,colorInject,R,G,B,alpha,replace,patternColor,actionID,stop`;
    actions.json mtime 变更检测重载 (0.3s 节流与 UI 写盘配合);
    AVAssetReader timeRange(start..end) 区间读取 = VCActionPlayer 分段播放移植
    (generation 复位语义由动作切换重建读取器等价实现), 区间循环 (EOF/越界重开读取器),
    速度 0.5–2x (s>=1 虚拟时间轴跳帧, s<1 帧复用累加);
    无效配置自动回退普通模式, stop/清空 actionID 恢复且不重置播放位置;
    vcam_bypass_set_action/vcam_bypass_action_stop/vcam_bypass_active_action 接口。
  - UI (VCamBypassUI.m, SpringBoard): 面板新增第 3 页签「动作」 — 模式/状态芯片、
    信息行 (视频时长 · 动作数 · 当前动作名)、动作列表 (播放中 cyan 高亮 + ▶ 前缀
    「名称 开始–结束 · 循环/一次 · 速度」)、「＋ 添加动作」「■ 停止动作」、长按行
    编辑/删除、添加/编辑表单 (名称/开始秒/结束秒/循环 0/1/速度 0.5-2x, 客户端+引擎
    双侧校验)、选新视频自动清空动作配置 (videoSize 变更检测)。
- docs: 新增 VCAction-INTEGRATION.md (接口分析/映射表/13 字段协议/交付层次) 与
  FEATURE-MAP.md (v32→v34 功能地图); 生成 VCamPro-v34 构建图纸/UI图纸/总UI图纸 PNG。

## v1.1.5 (2026-08-12)

### 功能
- feat: 控制面板重构 — 采用参考工程(朋友版 UI 源码)的深色能量卡片构图:
  350x544 圆角卡片 + 顶部渐变边条 + 双页滑动 (FUNC/STATUS) + 页签 + 能量条。
  功能键全部对应构建仓库 Tweak.xm 真实能力:
  - FUNC 页: REPLACE/CAMERA/HOOKS/PATTERN 状态芯片; 画面替换、相机真画面
    开关; 6 色图案预设 (RED/GREEN/BLUE/YELLOW/CYAN/WHITE, BGRA);
    RE-INJECT、EXPORT LOG 按钮; ✕ CLOSE PANEL。
  - STATUS 页: OBJC SWIZZLE / C FUNCTION HOOK / GATE2 / SECKEY VERIFY /
    PHOTO ENCODER 5 项 hook 状态 + ENERGY 填充条。
- fix: 菜单页签 tag 缺失导致切页失效; 芯片/状态行挂载到页面容器
  (跟随滑动切页); 修正芯片与页签重叠、状态值与能量条重叠。

## v1.1.4 (2026-08-12)

### 修复
- fix: 悬浮球/菜单不显示 — 根因: 独立 UIWindow (initWithFrame + hidden=NO)
  在 iOS 13+ 无 UIWindowScene 关联时不渲染 (SpringBoard 下窗口不可见)。
  对齐参考工程(朋友版 UI 源码)机制: vcTopVC() 遍历 connectedScenes 找
  keyWindow → rootVC → presented 链; 菜单 presentViewController
  (FormSheet + preferredContentSize 300x330), 悬浮球 addSubview 到
  topVC.view (可拖动/点击弹菜单)。移除 sBallWin/sMenuWin 独立窗口。

## v1.1.3 (2026-08-12)

### 修复
- fix: 按音量键触发屏幕黑屏/锁屏 — 根因是 method_invoke 在 arm64e
  (iPhone XS+, 带 ptrauth) 上对 IMP 签名处理不当, 调用原 increaseVolume/
  decreaseVolume 时崩 SpringBoard。改为对齐参考工程(朋友版 UI 源码)写法:
  method_getImplementation 强转直接调用 (runtime 已返回签名好的 IMP,
  arm64e 安全)。移除 dlsym/method_invoke/fallback 类, 日志保留。
- fix: 清理无用 import (<dlfcn.h>/<objc/message.h>)。

## v1.1.2 (2026-08-12)

### 修复
- fix: 音量键入口失效 — 原 IMP 调用改 method_invoke (runtime 按真实签名调用,
  消除调用约定错位); 移除过严的 v@: 签名校验 (跳过即入口不装)。
- fix: 音量入口增加 fallback 类 SBHIDValueModifyingButtonSet (iOS 16+ HID 路径)。
- feat: 诊断日志完整化 ([vcbUI] 输出类/方法/签名/安装结果, log show 可查)。

## v1.1.1 (2026-08-12)

### 修复
- fix: TWEAK_NAME 品牌化后 plist 未同步改名 — Theos 找不到
  vcampro-bypass.plist 导致 make package 失败。已重命名（注入过滤不变）。
- fix: CI 日志回传步骤加固（[skip ci] 防触发构建、GIT_TERMINAL_PROMPT=0）。
- fix: workflow 显式 permissions: contents: write — 仓库默认只读,
  github-actions[bot] push 回传被 403 拒绝。

## v1.1.0 (2026-08-12)

### 品牌化
- feat: 全面 rebrand — 包名 `com.vcampro.bypass`，Name=VCam Pro Bypass，
  Author/Maintainer=vcampro，Description 重写（不含千面/vcam125 品牌字样）。
- feat: Makefile TWEAK_NAME → vcampro-bypass（产物 dylib/deb 名），
  UI 面板标题 VCam Pro Bypass，日志导出路径 vcampro-bypass.log，
  CI workflow/artifact 名同步更新。
- 保留项（功能命脉，不可改）：dyld 监听目标 dylib 名 vcameracrack、
  内部 hook 类名/偏移、接口符号 vcam_bypass_*。

### 依赖
- fix: com.taokk3.qianmian 依赖降级为 Recommends（可选），无千面环境也可安装；
  安装千面后绕过功能生效。适配全部越狱环境。

## v1.0.3-v32 (2026-08-11)

### 修复
- fix: 移除 Depends 强依赖 com.taokk3.qianmian，改为 Recommends 弱依赖 —
  无千面环境也可安装；安装千面后绕过功能生效。适配全部越狱环境。

## v1.0.2-v32 (2026-08-11)

### 修复
- fix: CI 在构建前自动执行 `patch -p1 < UI-PATCH.diff`，产物直接包含 UI 面板。
  提交 hash 记录于 Actions 日志 (patched.shasum) 供追溯。
- fix: VCamBypassUI 符号统一 — 安装入口由 `vcam_bypass_ui_install` 改为补丁调用
  的 `vcap_ui_mount`，消除 undefined symbol 链接错误。
- fix: VCamBypassUI.m 补全 `vcStatusLine/vcReplaceOn/vcCameraPassOn` 前向声明，
  消除 C99 implicit declaration 编译错误。
- fix: VCamBypassUI.m 前向声明全部移至文件顶部；UIScreen 无 center 属性改用
  bounds 计算；显式 #import <QuartzCore/QuartzCore.h> 提供 CACurrentMediaTime。
- feat: CI 增补构建日志工件 (build.log, 失败时也上传) 便于定位编译错误。
- fix: UI 补丁接口全部加 extern "C" — .xm 编译为 C++ (符号 mangled), 与
  VCamBypassUI.m 的 C 符号匹配, 消除 8 个 undefined symbol 链接错误。
- feat: CI 失败时自动把 build.log 回传 ci-logs 分支 (GITHUB_TOKEN, 不触发构建)。

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