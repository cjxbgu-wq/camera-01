# CHANGELOG

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