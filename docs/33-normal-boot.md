# 正常 boot 与调试 ADB（2026-10-06）

system 产品现在开启 PRODUCT_BUILD_BOOT_IMAGE，由原厂 prebuilt kernel/DTB 和新增 prebuilt/boot-ramdisk.img 构建。ramdisk 为原厂原始压缩包，不含诊断 PID1 wrapper、init.stock 或 cache collector；原厂 first-stage init/fstab 保留。BOARD_MKBOOTIMG_ARGS 最后指定 stock ramdisk、OS 12.0.0、SPL 2024-03、stock cmdline，覆盖通用构建追加的 buildvariant，避免重复。

正常 boot 已从 m bootimage 输出解包验证：kernel、DTB、ramdisk 与原厂逐字节一致；加载地址/header v2/page size 与 stock 相同，cmdline 无 printk/loglevel 诊断参数。新 AVB hash footer 使用 NONE，搭配当前 flags=3 vbmeta。重建的 system 已确认 ro.adb.secure=0、persist.sys.usb.config=adb，并包含前述 early ADB init RC；免授权实际时机待实机测试。

产物 ~/S17Promini_LineageOS/artifacts/boot-normal-r1.img。先用 bootloader fastboot 写 boot，启动确认，再测试整包：

```powershell
adb reboot bootloader
fastboot flash boot .\boot-normal-r1.img
fastboot reboot
```

单独刷 boot 不会更新 system 内的 ADB 改动；后续安装 zip 会同时更新 system。原诊断 boot-kmsg-debug.img 保留用于排障；用户已确认正常 boot 成功启动；zip 首测失败，修复记录见后续文档。
