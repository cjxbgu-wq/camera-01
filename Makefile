TARGET = iphone:clang:latest:15.0
ARCHS = arm64 arm64e
INSTALL_TARGET_PROCESSES = SpringBoard mediaserverd
# [PATCH-v45] DynamicLibraries 布局 (参考资料: 千面已运行项目同款):
#   - dylib+plist 装 /var/jb/Library/MobileSubstrate/DynamicLibraries/
#   - TweakLoader(ellekit) 按 plist Filter (Bundles+Executables) 注入
#   - mediaserverd 在 Bootstrap resignList.plist 内(已重签名) -> daemon 可注入
#   - .roothidepatch 由 RootHidePatcher 安装时自动生成 (无需预置!
#     预置会导致 Error(256): failed to create symbolic link ... File exists)
# v43(DynamicPatches) 走错通道(PatchLoader 不覆盖系统进程), 已废弃.
THEOS_PACKAGE_SCHEME = rootless

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = vcampro-bypass

vcampro-bypass_FILES      = Tweak.xm Modules/VCamBypassUI.m
vcampro-bypass_LDFLAGS    = -Wl,-x -Wl,-S -lsubstrate
vcampro-bypass_FRAMEWORKS = Foundation Security CoreVideo VideoToolbox UIKit QuartzCore AVFoundation CoreImage CoreMedia
vcampro-bypass_CFLAGS     = -fobjc-arc -Wno-deprecated-declarations -Wno-unguarded-availability-new -O2

include $(THEOS_MAKE_PATH)/tweak.mk