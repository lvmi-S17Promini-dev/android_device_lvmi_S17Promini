# 实机测试（待执行）

更新：用户确认 adb reboot 可用，按键组合不能进入 fastboot/recovery；BROM 可通过关机后同时按住音量 +/− 插 USB 进入。优先 fastboot boot 临时测试，回退方式见 `05-recovery-path.md`。

目前主机 `adb devices -l` 没有设备；没有进行任何刷写。无需提前 root 或刷 Magisk。

## 补充信息（原厂系统，无 root）

```bash
adb shell wm size
adb shell wm density
adb shell getprop ro.boot.verifiedbootstate
adb shell getprop ro.boot.slot_suffix
adb shell getprop ro.boot.boot_devices
adb shell getprop ro.hardware
adb shell ls -l /dev/block/by-name
```

记录进入 bootloader/recovery 的按键组合。在 bootloader 中记录：

```bash
fastboot --version
fastboot devices
fastboot getvar all 2>&1
```

分享输出时可隐藏序列号。getvar all 中重点看 unlocked/secure、partition-size:recovery、是否支持 boot。MTK LK 是否实现 fastboot boot 必须实测。

## 首次临时启动（历史步骤：本机原厂对照也失败，暂不继续）

可使用已编译的主机 fastboot；临时启动不写分区。构建与静态检查通过后执行：

```bash
~/android3/lineage/out/host/linux-x86/bin/fastboot boot ~/android3/lineage/out/target/product/S17Promini/recovery.img
adb devices -l
adb shell id
adb shell getprop sys.usb.controller
adb shell getprop sys.usb.state
adb shell getenforce
adb shell ls -l /dev/block/by-name
```

目标：能进 recovery、画面/按键正常、USB adb state、`id` 返回 uid=0。不点击恢复出厂、不 format data、不刷 super/vbmeta。
若 fastboot 返回 unknown command/boot unsupported，这是 LK 能力限制，需保存完整输出，再安排仅 recovery 分区的持久化测试和 stock recovery 回退；尚未执行该步骤。

## 获取日志

```bash
adb pull /tmp/recovery.log
adb shell dmesg > recovery-dmesg.txt
adb logcat -b all -d > recovery-logcat.txt
adb shell ls -l /sys/class/udc
adb shell ls -l /sys/class/graphics
adb shell cat /proc/cmdline
```

黑屏但 ADB 可用：检查 recovery.log 的 minui/fb、屏幕尺寸与方向；USB 不枚举：检查 UDC/configfs/SELinux AVC；无法启动：记录 fastboot 错误、屏幕内容及是否重启。无法运行 adb 时先提供 bootloader 错误和现象。

recovery 基础通过后，再验证菜单进入 fastbootd、`fastboot getvar is-userspace` 是否 yes，以及可查询 logical partitions；此步先不刷写。

最新结果：原厂和自编镜像 fastboot boot 均失败并重启回系统，详见 06-device-test.md。下一步验证从 bootloader 直接 reboot recovery，暂不执行 flash。

最新入口验收：用户已确认 fastboot reboot recovery 可进入原厂 recovery。后续使用 07-flash-test.md 的独立分区测试流程。
