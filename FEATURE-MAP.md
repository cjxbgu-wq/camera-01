# 功能对齐清单：构建仓库 vs 参考源码

## A. 现有功能 — 与参考源码的对应关系

| 构建仓库现有功能 | 参考源码对应 | 关系说明 |
|---|---|---|
| 运行时 hook 链（dyld add_image → tryObjCSwizzle + MSHookFunction gate2/SecKey/PhotoEnc） | vcamplus 的 MSHookMessageEx + method_setImplementation 双轨 hook | **机制不同**：仓库 hook vcameracrack.dylib 内部方法；参考源码 hook AVCaptureSession 管线。目标一致（替换相机画面），实现不同，不可直接对齐 |
| 画面替换开关 gReplaceEnabled | 无直接对应（参考源码用 enabled 标志文件 + gTweakEnabled） | 开关概念对应，实现为仓库自有 |
| 相机真画面开关 gCameraPassEnabled | 主源码 photoFlag=1 路径跳过（注释 L108） | 对应，逻辑同源 |
| 纯色图案替换（v23_getTestPattern） | 参考源码无纯色图案模式 | **仓库独有**（验证端到端传输），参考源码无此功能 |
| 6 色图案预设 UI | 借鉴版 UI 有颜色按钮（FWCtrl 色板） | 功能近似（颜色选择），实现不同 |
| RE-INJECT（重试 swizzle） | 参考源码无此按钮 | **仓库独有** |
| EXPORT LOG（日志导出） | 参考源码有 vcam_log 但 UI 无导出按钮 | 状态近似，按钮为仓库自有 |
| 能量卡片 UI（350×544 双页） | 借鉴版同款构图（标题/边缘渐变/chips/FUNC/STATUS） | **完全对应**（v1.1.5 已照抄构图） |
| 音量键入口 + 悬浮球 | 借鉴版同款（vcam_topVC + 音量键） | 完全对应 |
| 5 项 hook 状态页 | 借鉴版 STATUS 页同概念 | 对应 |

## B. 需要添加的功能键（本次构建，借鉴参考源码）

| 新增功能键 | 参考源码位置 | 实现方式 |
|---|---|---|
| **SELECT VIDEO 选择视频** | 借鉴版 tag1（PHPicker 相册 + AVAssetExportSession Passthrough 重封装 → video.mp4，L5241-5303） | 完整移植：相册选视频 → 拷贝到 `/var/jb/var/mobile/Library/vcamplus/video.mp4` |
| **PICK IMAGE 选择图片** | 借鉴版 tag2（相册 → image.jpg，L5304-5321） | 完整移植 |
| **COLOR INJECT 颜色注入** | 主源码 vcam_applyColorInject（L2033）；借鉴版 tag5 取色器 | **简化版**：RGB+alpha 数值输入全屏注入（不做人脸检测部分，见 C） |
| **ROTATE 旋转** | 主源码 vcam_applyVideoTransforms（L1990）；借鉴版 tag4 | 移植：90/180/270 旋转 + 翻转 |
| **PLAY / PAUSE 播放暂停** | 主源码 case 107/108（L4213-4214） | 移植：gVideoPaused + gPausedFrame 暂停帧 |
| 视频/图片渲染管线 | 主源码 vcam_openReader（L1718）/ vcam_readFrame（L1738）/ vcam_renderToNewBufferMatching（L2382，aspectFit 黑边） | 移植：AVAssetReader 读 BGRA 帧 → aspectFit → 现有 VTPixelTransferSession 输出 |
| 跨进程 controls 文件 | 主源码 VCAM_FLAG + vcam_readControls（L1623）+ Darwin 通知 | 移植：UI(SpringBoard) 写文件 → 替换进程 0.3s 轮询 |
| STATUS 页 SOURCE FILES 状态 | 借鉴版 L5978-5981（文件大小显示） | 移植：video.mp4/image.jpg 大小 + 当前激活源 |

## C. 参考源码有 — 本构建**不做**（理由）

| 参考源码功能 | 不做理由 |
|---|---|
| MJPEG LIVE STREAM（借鉴版 tag3 + MJRcv socket 接收） | 依赖 PC 端推流端配合，无法自测验证；一期不做，后续可加 |
| COLOR BOOST / REDUCE（FWCtrl + UIScreen 私有截图 API 三级回退） | 私有 API 复杂易崩；与虚拟摄像头场景不匹配 |
| 人脸检测颜色注入（主源码 Vision VNFaceLandmarks + 轮廓 mask，L2033-2131） | 在 mediaserverd 中跑 Vision 检测开销大、风险高；简化为全屏 RGB 注入 |
| 视频预览窗 PTWnd + OVLay 覆盖层（虚浮窗版） | 仓库已有悬浮球 + 菜单，预览窗非必需 |
| 多视频索引 1.mp4~6.mp4（vcam_switchVideo） | 一期单视频 video.mp4；索引切换逻辑已了解，后续可加 |
| 授权体系（_isAuth / VCAM_CHK_A / 假人脸 / 延迟降级） | 仓库定位是 bypass 工具，参考源码的授权保护是"被绕过对象"逻辑，不适用 |
| WebContent C 层 hook（CVPixelBufferLockBaseAddress/IOSurfaceLock） | 参考源码针对网页 OCR 场景；仓库目标进程无此需求 |

**结论**：A 表 = 已对齐或仓库自有；B 表 = 本次新增 8 项（全部有参考源码依据）；C 表 = 明确不做的 7 项（有理由）。功能键范围以 A+B 为准。

## D. v34 — VCActionSystem 独立模块集成（对照参考工程源码）

| 参考工程（VCActionSystem） | 本仓库 v34 实现 | 说明 |
|---|---|---|
| VCActionManager.validateAction（id/name 非空、start≥0、end>start、end≤视频时长、speed>0） | 引擎 vcam_applyActionSelection + 表单校验：start/end/速度范围双侧校验 | 无效配置自动回退普通模式 |
| VCActionStorage JSON `{version,videoName,duration,actions[]}`（Documents/ActionConfigs/<视频名>.json） | 同 schema 落盘 `/var/jb/var/mobile/Library/vcamplus/actions.json`（videoName+videoSize 换视频检测） | 同构移植 |
| VCActionPlayer：generation 取消旧请求、loop、speed、segment 播放 | AVAssetReader timeRange 区间读取；动作切换重建读取器（等价 generation）；EOF/越界重开=循环；s≥1 跳帧 / s<1 帧复用 | 引擎等价移植 |
| VCVideoFrameProvider 协议（requestFrameAtTime:completion:） | 不适用 — 仓库读取器为同步拉帧模型 | 按 README 约束仅概念对应，不硬套协议 |
| VCActionEditorViewController（表单+按钮面板） | 面板第 3 页「动作」：动作列表 + 添加/编辑表单 + 停止 | UI 独立重构 |
| VCActionPanelView / VCActionButton | mkActionRow 动作行（播放中高亮、长按编辑/删除） | UI 独立重构 |
| VCTimelineView 时间轴 | 未做（列表展示 开始–结束 区间） | 一期不引入时间轴绘制 |
| UI(SpringBoard) 写 actions.json + controls 13 字段 → 替换进程 0.3s 节流读 + mtime 重载 | 跨进程协议（字段 11=actionID, 12=stop） | 独立设计的跨进程通道 |
