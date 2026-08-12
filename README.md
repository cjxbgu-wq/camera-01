# VCam Pro Bypass (camera-01)

VCam Pro 摄像头 License 校验绕过 Tweak（iOS 越狱，Theos 构建）。

## 特性

- 运行时绕过：dyld add_image 监听目标 vcam dylib 加载，**零磁盘文件修改**
- 三层 hook：ObjC swizzle（LicenseCore 5 方法 + VCamCore 3 方法）、C 函数 hook
  （gate2/SecKeyVerifySignature/BWPhotoEncoder）、ivar 强制写入 + 100ms enforcer
- 画面替换：第三方/网页相机显示红色测试图案，Apple 相机显示真画面（防黑屏）
- **UI 控制面板（v32）**：悬浮球 + 菜单 + 音量键入口（见下方补丁说明）

## 源码零修改原则

`Tweak.xm` 入库保持原样，一切功能以补丁交付：

| 文件 | 说明 |
|---|---|
| `Tweak.xm` | 核心源码（v31，**不直接修改**） |
| `UI-PATCH.diff` | UI 补丁（Tweak.xm +81 行 + Makefile 品牌化），`patch -p1` 应用 |
| `Modules/VCamBypassUI.h/.m` | 独立 UI 模块（随补丁一起编译） |

## 构建

GitHub Actions（`.github/workflows/build.yml`）push 到 main 自动构建：

1. 检出仓库
2. 自动 `patch -p1 < UI-PATCH.diff`（补丁失败即构建失败）
3. Theos + iOS 16.5 SDK 编译 `make package FINALPACKAGE=1 STRIP=1`
4. 产出 artifact：`vcampro-bypass-deb`、`build-log`（失败时回传 `ci-logs` 分支）

本地构建：

```bash
git clone https://github.com/cjxbgu-wq/camera-01
cd camera-01
patch -p1 < UI-PATCH.diff
make package FINALPACKAGE=1 STRIP=1
```

回滚：`git checkout -- Tweak.xm Makefile` 完全还原。

## 安装

1. 下载 Actions artifact `vcampro-bypass-deb`（或本地 `packages/*.deb`）
2. 拷入手机 `scp` / 或直接用 Sileo/Zebra 安装 deb
3. 重启 SpringBoard（`killall -9 SpringBoard`）

## UI 面板（v32）

| 入口 | 操作 | 作用 |
|---|---|---|
| 音量 + 再按音量 −（1.5s 内） | 组合键 | 弹出悬浮球 |
| 音量 − 再按音量 +（1.5s 内） | 组合键 | 呼出/关闭菜单 |
| 悬浮球单击 | 单击 | 开关菜单 |
| 悬浮球拖拽 | 拖拽 | 移动位置 |
| 悬浮球颜色 | 绿=全通 黄=部分 红=未注入 | 状态指示 |

菜单功能键 ↔ 源码接口对应：

| 功能键 | 接口 | 源码作用点 |
|---|---|---|
| 画面替换 | `vcam_bypass_set_replace` | `v23_doReplace` 总闸 `gReplaceEnabled` |
| 相机真画面 | `vcam_bypass_set_camera_pass` | `photoFlag=1` 跳过分支 |
| 重新注入 | `vcam_bypass_retry` | `tryObjCSwizzle(100)` |
| 导出日志 | `vcam_bypass_logs` | 环形缓冲 → `/var/jb/var/mobile/Library/vcampro-bypass.log` |
| 隐藏悬浮球 | `vcHideBall` | 隐藏窗口 |

## 状态接口（补丁导出，UI 模块调用）

`vcam_bypass_status` / `set_replace` / `set_camera_pass` / `set_pattern_color` /
`get_replace` / `get_camera_pass` / `retry` / `logs`

> 注意：Tweak.xm 编译为 C++，接口已 `extern "C"` 包裹以匹配 ObjC 模块的 C 符号。

## 版本

- v31：运行时绕过 + 画面替换（基线）
- v32：UI 控制面板（补丁交付，CI 构建自动合并）
- v1.1.0：品牌化（com.vcampro.bypass），千面依赖降级为可选，全环境可安装
