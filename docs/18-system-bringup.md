# System-only 试启动（2026-10-06）

目标：lineage_S17Promini_system-userdebug。这是复用原厂 boot/kernel/vendor 的首次启动配置，不是完整设备移植或 OTA 产品。
Lineage product/system_ext 融合进 system，提供 VNDK31，使用 GSI skip_mount 配置跳过原厂 product/system_ext 挂载；GLES 是试启动兼容性设置，尚未在本机验证。
独立 recovery 产品 lineage_S17Promini 保持 r5 配置。

```bash
cd ~/android3/lineage
source build/envsetup.sh
lunch lineage_S17Promini_system-userdebug
set -o pipefail
m -j8 systemimage vbmetaimage 2>&1 | tee ~/S17Promini_LineageOS/extracted/metadata/build-rom-system-user.log
```

预期输出：out/target/product/S17Promini/system.img 和 vbmeta.img。构建配置已通过解析并开始编译，约25%时用户接手；当前无后台构建进程，可使用已有缓存继续。完整构建及实机启动未验证，不提供刷写指令。
boot/vendor/product 原分区保留思路尚待首次启动验证；完整 HAL 兼容、SELinux/FBE、ROM/OTA zip 均未完成。这个目标当前不使用 m bacon。
新增 mtkclient-to-fastboot 参考已读：通过 watchdog 寄存器重定向，不是写 recovery 分区。本机尚未实测，用户准备测试；不覆盖既有 mtkclient 环境。
