# charger 息屏后背光仍亮（2026-10-06）

用户实测 r2：充电动画和 ADB 可用；动画结束后画面变黑但背光仍亮，短按电源恢复动画而背光亮度不变。

本轮输入位于工作目录 charger-debug。PowerShell 文件解码后另存 normalized.log，原件保留，不提交设备日志。

## 证据

- charger 服务 running，SELinux Enforcing。
- 内核在约 14.61s 和 38.25s 收到 charger 的 fb_notify(blank=4)，约 30.56s 收到 blank=0，与用户短按重新显示动画的反馈一致。
- 息屏路径进入 primary_display_suspend/mtkfb_blank，PWM 记录 `backlight is off, power:(0)`。未看到 `ioctl(): blank` 报错，也未看到背光操作相关的 charger AVC。调用链中的 dump_stack 不等于内核崩溃。
- `/sys/class/leds/lcd-backlight` 的真实路径为 `/sys/devices/platform/leds-mt65xx/leds/lcd-backlight`，目录标签是 generic sysfs；brightness 读取为 0，max_brightness 为 255。因此这个 LED class 缓存值不能作为物理背光已经关闭的证据。
- stock kpoc_charger 含 `start_backlight` / `stop_backlight` 及 `No light service, cannot set brightness` 字符串，支持它另外通过 light service 控制亮度的判断。当前 Lineage 的 HealthdDraw::blank_screen 仅调用 gr_fb_blank，没有独立 light HAL/brightness 设置。

目前推测：framebuffer blank 没有完整关闭本机实际背光，可能需要独立的亮度控制；尚未确认直接写 LED 节点是否能解决，不应立刻发布“已修复”镜像。

## 最小实机对照

保持 charger 画面已黑、背光仍亮时，先写 0，观察背光是否真正关闭：

```powershell
adb shell 'echo 0 > /sys/class/leds/lcd-backlight/brightness'
```

若没有变化，再用 128→0 排除当前缓存值为 0 导致重复设置被跳过。观察两秒内及之后的背光变化：

```powershell
adb shell 'echo 128 > /sys/class/leds/lcd-backlight/brightness; sleep 2; echo 0 > /sys/class/leds/lcd-backlight/brightness'
adb shell dmesg > .\charger-backlight-test-dmesg.txt
adb shell 'ls -lZ /sys/class/leds/lcd-backlight/brightness; ls -l /sys/class/leds/lcd-backlight/' > .\charger-backlight-nodes.txt
```

必要时写 128 恢复可见亮度；这是临时对照，不修改持久配置：

```powershell
adb shell 'echo 128 > /sys/class/leds/lcd-backlight/brightness'
```

若显式亮度控制有效，再把控制接入 charger 的 blank/unblank，并对真实背光节点添加精确标签及所需权限。若无效，则继续定位原厂 light HAL/面板背光实现，不通过全局 permissive 或宽泛 sysfs 写权限掩盖硬件路径问题。

本次日志另有 charger 对 gpu_device/dri 的 search 拒绝（随后 framebuffer 显示与 blank 可用），health HAL 读取未知 sysfs/type 被拒绝，以及 init 写 USB cmode 被拒绝；这些不自动等同于背光根因，须分别按真实节点和调用用途处理。本轮未改 RC、策略或镜像。

## 128/0 对照结果

用户反馈画面已黑时写 128 和 0 均不改变物理背光。新日志证实写入进入驱动：501.779s 的 Set Backlight directly L:128，PWM 请求 level_1024=514，随后硬件状态日志却报 on (1023)；507.318s 的 L:0，PWM 请求 level_1024=0。未观察到这些 shell 写入被 SELinux 拒绝。

这排除了“shell 没写进去”和“只更新 LED class 缓存而未进入 PWM 调用”两种解释，但不能从请求日志证明 PWM 最终硬件输出。尤其本次测试在 panel suspend 后进行，显示/PWM 时钟状态可能影响结果。

原厂 lights.mt6765.so 也使用 `/sys/class/leds/lcd-backlight/brightness`；因此没有证据支持换成原厂 light HAL 就必然解决。原厂 overlay 的 lcd-backlight led_mode=5，对应请求日志中的 BLS PWM 路径。当前不改 DTB、不尝试 GPIO 或寄存器写入。

下一步短按电源，让动画正在显示时执行 128→0→128（各间隔 1 秒），对比 panel active 与 suspended 时的结果：

```powershell
adb shell 'echo 128 > /sys/class/leds/lcd-backlight/brightness; sleep 1; echo 0 > /sys/class/leds/lcd-backlight/brightness; sleep 1; echo 128 > /sys/class/leds/lcd-backlight/brightness'
adb shell dmesg > .\charger-backlight-awake-dmesg.txt
```

若 active 时控制有效，则验证在 FBIOBLANK(POWERDOWN) 前关闭亮度、UNBLANK 后恢复的顺序；若 active 时也无效，则进一步取正常 Android 下相同亮度操作的对照，定位 PWM/panel/bootmode 差异，暂不发布背光修复镜像。

用户已确认 active 对照中写 0 出现灭灯，日志也显示请求 PWM 514 时读回 514。后续实现见 [r3 控制顺序修复](45-charger-backlight-order.md)。
