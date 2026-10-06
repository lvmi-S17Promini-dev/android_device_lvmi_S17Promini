# charger 背光控制顺序修复 r3（2026-10-06）

用户实测 r2 的动画和免授权 ADB 正常；自动息屏后画面黑但背光亮，短按电源可恢复动画。息屏后写 LED brightness=128/0 无效，而动画显示期间执行 128→0→128，用户确认中间出现灭灯。

亮屏对照日志：829.629s 请求 PWM level_1024=514，驱动状态也读回 on(514)；830.645s 写 0；831.664s 再写 128。此前在 panel suspend 后请求 514，却读回 on(1023)。这些结果支持背光写入应在显示/PWM 时钟仍有效时执行，而非在 FB_BLANK_POWERDOWN 后执行。

## 实现

给 system/core 的 HealthdDraw 增加可选的 LED brightness 控制。设备 charger 服务通过 CHARGER_BACKLIGHT_PATH 指定 `/sys/class/leds/lcd-backlight/brightness`，CHARGER_BACKLIGHT_BRIGHTNESS 指定 128。只在该服务设置环境变量时启用；其他设备/进程不设置时保留原 gr_fb_blank 行为。

- minui 初始化完成、屏幕已恢复后，读取当前正亮度并恢复；当前值为 0 时使用设备配置的 128。
- blank(true)：先保存当前正亮度，写 0，再执行 framebuffer blank。重复息屏读到 0 不覆盖之前保存的亮度。
- blank(false)：先 framebuffer unblank，再恢复保存的亮度。
- 写入失败记录具体节点、请求值和 errno；成功记录 `charger: backlight: brightness=N`，便于核对与 fb blank 的先后顺序。

框架改动保存为 `patches/system-core-charger-backlight.patch`。新源码 checkout 需在 system/core 仓库应用该补丁，然后构建；设备 RC 单独更新不足以修复顺序：

对应 system/core 提交为 `44720bd57`；若 checkout 已包含该提交，无需重复应用补丁。

```sh
git -C system/core apply --check ../../device/lvmi/S17Promini/patches/system-core-charger-backlight.patch
git -C system/core apply ../../device/lvmi/S17Promini/patches/system-core-charger-backlight.patch
source build/envsetup.sh
lunch lineage_S17Promini-userdebug
m -j8 systemimage vbmetaimage
```

## SELinux

使用 genfscon 仅为真实文件 `/devices/platform/leds-mt65xx/leds/lcd-backlight/brightness` 添加私有类型 sysfs_s17_backlight。charger 仅获得该类型文件的 rw_file_perms，不获得整个 generic sysfs 的写权限。

同一文件保留 hal_light_server 的读写权限，支持正常 Android 的 vendor light HAL；vendor_init 获得该文件 setattr，以继续执行原厂 chown。目录仍使用原有标签。SELinux 保持 Enforcing，不添加 permissive 域，不修改 kernel、DTB、vendor 镜像或无关 AVC。

## 实机验证

构建与静态验证完成：systemimage/vbmetaimage 成功；RC verifier、C++ 编译和构建的策略检查通过；输出 charger 含新的背光控制，RC 与源码一致；用 init 同样的运行时 secilc 参数将新策略和 stock vendor CIL 合并成功。合并策略中 charger/adbd 不是 permissive，hal_light_server 包含实际 vendor light 域；源码补丁反向检查和 git diff --check 通过。

测试产物导出到 `~/S17Promini_LineageOS/artifacts/rom-charger-backlight-r3/`，包含 system.img、vbmeta.img 和 build.json（镜像 SHA256、框架版本及补丁摘要）。尚未刷机，自动息屏及正常 Android 亮度调节仍待实机验收。

在现有 fastbootd 中刷本次 system.img，沿用已验证的 flags=3 vbmeta。正常启动后确认系统亮度调节仍可用；完全关机再插电，检查动画可见、自动息屏时背光真正关闭、短按电源恢复画面和亮度、重复几次都正常；ADB 应持续可用。

```powershell
adb shell dmesg > .\charger-backlight-r3-dmesg.txt
adb shell 'ls -lZ /sys/class/leds/lcd-backlight/brightness; cat /sys/class/leds/lcd-backlight/brightness; getenforce' > .\charger-backlight-r3-state.txt
```

息屏日志应先出现 `backlight: brightness=0` 再出现 `fb_notify(blank=4)`，亮屏先 `blank=0` 再恢复正亮度。若仍不灭灯，应保留日志，继续核对 driver suspend 是否重新开启了背光；不能把构建通过当作实机验收。

实机补充：r3 未灭灯，日志显示 brightness 写入因 DAC 文件权限失败，而非顺序代码未执行；后续修复见 [r4 文件权限](46-charger-backlight-dac.md)。
