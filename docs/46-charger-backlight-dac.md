# charger 背光文件权限修复 r4（2026-10-06）

用户反馈 r3 仍灰屏、有背光。新 charger-r3 日志确认补丁已生效，但每次写入均失败：14.222s 写 0、25.978s 写 128、33.326s 写 0 报 Permission denied。未见对应背光 AVC。节点状态是 system:system 0644、sysfs_s17_backlight；标签已正确。

根因是 DAC：charger 以 root 运行，但 RC 显式限制 capabilities 为 SYS_BOOT/SYS_TTY_CONFIG/BLOCK_SUSPEND，没有 CAP_DAC_OVERRIDE。文件归 system 所有，system 组仅能读，因此 charger 也不能写。之前 root ADB shell 对照的权限环境不同，不能据此推断 charger 同样可写。

原厂 init.mt6765.rc 在 on boot 中执行 brightness 的 chmod 0664 和 chown system system；charger 模式跳过正常 boot 事件，只执行 on charger 中的 chown，因此仍保留 0644。

## 修复

设备 RC 新增 `on init && property:ro.bootmode=charger`，在 class charger 启动前将唯一的 LCD brightness 文件 chmod 0664。charger 已有 system supplementary group，于是无需 CAP_DAC_OVERRIDE 即可写入；沿用正常 Android 使用的模式。

为 init 增加该私有背光类型文件的 setattr 权限，以执行 chmod。保留 r3 的精确 genfscon、charger 读写权限和背光先关再 blank 的顺序，未继续修改框架源码，未增加 charger capabilities，未关闭 SELinux。

当前 r3 也可先做临时验证，无需刷机：

```powershell
adb shell 'chmod 0664 /sys/class/leds/lcd-backlight/brightness'
```

随后短按电源，等动画自动结束，确认是否灭灯。root shell 只改变一次文件模式，重启后由 r4 RC 自动设置。

用户已确认临时 chmod 后自动息屏时背光关闭，验证了 DAC 修复的效果。

构建和静态验证：systemimage/vbmetaimage 成功，RC verifier 和 git diff --check 通过；输出 RC 与源码一致；新 init setattr 规则存在，使用 init 的运行时参数合并 stock vendor 策略成功，charger 保持 Enforcing。产物导出到 `~/S17Promini_LineageOS/artifacts/rom-charger-backlight-r4/`，包含 system.img、vbmeta.img 及 SHA256 清单 build.json。r4 冷启动自动设置权限及正常 Android 亮度调节尚待复验。

后续反馈：用户认为当前基本可用并要求提交，保留 r4 方案；没有额外推断每项冷启动/正常系统测试均已逐项验收。

## 实机验收

刷 r4 的 system.img 后完全关机再插电：brightness 应为 system:system 0664、sysfs_s17_backlight；dmesg 应出现成功的 `backlight: brightness=0`，而不是 cannot write / Permission denied。自动息屏应灭灯，短按应恢复亮度，重复循环及正常 Android 亮度调节也需测试。

```powershell
adb shell 'ls -lZ /sys/class/leds/lcd-backlight/brightness; getenforce'
adb shell dmesg > .\charger-r4-dmesg.txt
```
