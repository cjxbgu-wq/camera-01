# VCActionSystem 集成分析 (v34 动作分段模块)

来源: `C:\Users\admin\Desktop\VCActionSystem` (独立 iOS ObjC 视频动作分段触发系统)
交付红线: 所有改动只进 `UI-PATCH.diff` (v32+v33+v34), 仓库源码零修改, CI `patch -p1` 构建。

## 1. VCActionSystem 接口清单

### Models
- `VCActionModel`: actionID/name/startTime/endTime/loop/speed; SecureCoding + dictionaryRepresentation;
  JSON 字段: `{id,name,start,end,loop,speed}`, 校验: id/name 非空, start>=0, end>start, speed 0.1~4
- `VCVideoModel`: url/duration/frameRate/naturalSize/displayName

### Managers
- `VCActionManager`: add/update/remove/removeAll/actionWithID/validate(视频时长上界)/按 start 排序
- `VCActionStorage`: JSON 存取 Documents/ActionConfigs/<videoName>.json, schema `{version,videoName,duration,actions[]}`
- `VCVideoManager`: 异步加载视频元数据 (duration/frameRate/naturalSize)

### Player
- `VCActionPlayer`: loadVideoURL / playAction(start,end,loop,speed) / stop / invalidate;
  generation 计数取消旧请求; boundary + periodic observer 精确到边界; speed 0.5~2
- `VCVideoFrameProvider` (协议): `requestFrameAtTime:completion:` + `cancelPendingRequests`
  —— README 明确: 接入外部项目只适配此抽象, 不让 Manager/UI 依赖目标核心

### UI
- `VCActionEditorViewController`: 选视频 + 表单添加/更新 + 保存/加载配置 + 动作按钮触发
- `VCActionPanelView`/`VCActionButton`: 动作按钮列表 (actionID)
- `VCTimelineView`: 时间轴展示

## 2. 匹配映射 (VCActionSystem → VCamPro v34)

| VCActionSystem | VCamPro v34 落地 |
|---|---|
| VCActionModel + VCActionStorage (JSON) | `/var/jb/var/mobile/Library/vcamplus/actions.json`, schema 原样复用 `{version,videoName,duration,actions[]}` |
| VCActionManager 校验/排序 | 移植为 v34 校验 (UI 侧 add 时: start>=0, end>start, end<=时长, speed 0.5~2), 数组按 start 排序 |
| VCActionPlayer.playAction (区间+loop+speed+取消旧请求) | mediaserverd 侧 v34 动作引擎: 读取器 `timeRange(start..end)` 区间化; EOF 重开=循环; 采样时间驱动变速; 新动作直接覆盖 controls 即取消旧请求 |
| VCVideoFrameProvider (独立抽象) | `vcam_readVideoFrame` 升级: 区间寻址 + 循环 + 变速 (保持顺序读, 满足"只适配帧提供器"原则) |
| VCActionPanelView/ActionButton | VCMenuVC 新增第 3 页"动作": 动态动作按钮列表, 点击=播放该区间, 播放中高亮 |
| 表单添加/更新/删除 | UIAlertController (名称/开始/结束/循环/速度), 校验后写 actions.json |
| 保存/加载配置 | 自动: 选新视频时清空 actions.json (对齐参考行为 removeAllActions) |

## 3. 跨进程协议 v34

controls 文件 `enabled` 扩展为 13 字段 (v33 的 11 字段 + 追加 2):

```
1,rot,flip,pause,colorInject,R,G,B,alpha,replace,patternColor,actionID,stop
0  1    2    3    4          5 6 7 8     9      10           11       12
```

- 字段 11 `actionID`: 当前动作 ID (空串 = 普通视频播放模式)
- 字段 12 `stop`: 一次性停止信号 (1 = 恢复普通模式, 处理后清零)
- 读写: UI(SpringBoard) 写, 替换进程 vcam_readControls 0.3s 节流读
- `actions.json` 由 UI 独写、替换进程只读; 替换进程按 mtime 变更检测重载
- 动作引擎行为:
  1. actionID 非空 → 查 actions.json; 未找到 → 回退普通模式
  2. 找到 → 读取器以 timeRange(start..end) 打开 → 按帧输出
  3. EOF → 以同 timeRange 重开读取器 = 循环
  4. speed s: 采样时间驱动, 输出时间轴按 1/s 倍率推进 (s>1 跳帧, s<1 复用当前帧)
  5. stop/清空 actionID → 恢复普通视频播放 (位置不重置)
  6. v33 暂停/旋转/颜色注入/替换开关 与动作模式正交叠加

## 4. 补丁交付层次

```
HEAD (仓库源码 v31 基线, 零改动)
  └─ UI-PATCH.diff [v32 UI 接口 + v33 视频/图片管线 + v34 动作分段]
        └─ CI: patch -p1 < UI-PATCH.diff → make package → .deb
```

涉及文件 (全部走补丁):
- `Tweak.xm`: v34 动作引擎 + vcam_applyControls/readVideoFrame 扩展
- `Modules/VCamBypassUI.h`: 动作相关接口声明
- `Modules/VCamBypassUI.m`: 第 3 页"动作" + 弹窗表单 + actions.json 读写
- `Makefile`: 不变 (AVFoundation/CoreImage/CoreMedia/QuartzCore 已含)
