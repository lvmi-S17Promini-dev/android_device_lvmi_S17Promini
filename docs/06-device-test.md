# 用户实机信息（2026-10-05）

测试主机：Windows PowerShell。原厂 Android adb 可用。屏幕 `wm size`：384x854。

fastboot getvar all 关键值：

```text
max-download-size: 0x8000000
logical-block-size: 0x200
erase-block-size: 0x80000
hw-revision: ca00
partition-size:recovery: 2000000
partition-size:boot: 2000000
partition-size:super: 1a93d6000
partition-size:md_udc: 169a000
partition-type:md_udc: ext4
partition-size:metadata: 2000000
partition-type:metadata: raw data
partition-size:preloader: 40000
unlocked: yes
secure: no
kernel: lk
product: r65v3_pmz_w1a
is-userspace: no
slot-count: 0
version-baseband: MOLY.LR12A.R3.MP.V311
version-bootloader: r65v3_pmz_w1a-221ef069a60-2025091610304
version: 0.5
```

用户列出的 GPT 分区尺寸与现有备份一致；preloader 在 fastboot 中可见不等于已备份，仍需区分 eMMC boot 区域。version=0.5 是设备 fastboot 协议报告，不是 Windows host fastboot.exe 版本。

用户测试：

```text
fastboot boot .\recovery.img
Sending 'boot.img' (20268 KB) OKAY [0.559s]
Booting FAILED (Status read failed (Too many links))
fastboot: error: Command failed
```

20268 KiB 与当前自编 recovery 的 20754432 bytes 完全吻合，推测测试的是自编镜像；不应当作原厂 recovery 临时启动已失败的证据。

该错误是主机 transport 在读取 boot 命令状态时失败，没有得到明确的 remote FAIL reason；不能确定 LK 是不支持命令、崩溃、开始跳转内核，还是主机 USB/驱动出错。Sending 成功只证明 download 阶段通过。
本地源码依据：system/core/fastboot/fastboot_driver.cpp 的 HandleResponse 中 transport_->Read 失败生成 Status read failed；usb_windows.cpp 的 AdbReadEndpointSync 失败返回 -1。

下一步取证：执行后设备屏幕/是否自动重启；adb devices -l 与 fastboot devices；Windows fastboot --version。若 ADB 显示设备，先读取 ro.bootmode/ro.build.fingerprint/ro.lineage.version 区分 recovery 与原厂 Android，再取日志。若自编镜像没有启动，使用原厂 stock_imgs/recovery.bin（32 MiB，原封不动，可改名 recovery-stock.img）做同一 boot 命令基线，不执行 flash。

当前没有实机 recovery 成功证据，不进入 ROM/zip 阶段，不因该错误修改 LK 或刷 vbmeta。原镜像与 SHA256 保持不动，屏幕信息先记录；待设备反应确认后决定 recovery UI 修改与重编译。

## 原厂镜像对照结果：同样失败

```text
fastboot boot .\recovery.bin
Sending 'boot.img' (32768 KB) OKAY [0.902s]
Booting FAILED (Status read failed (Too many links))
fastboot: error: Command failed
```

用户观察：屏幕显示 `usb transfering....`，随后重启；电脑依次观察到 BROM、preloader，最后正常启动原厂 Android。原厂与自编镜像均无法通过当前 fastboot boot 路径启动。

结论：暂时弃用 RAM 临时启动路线；失败不能单独归因于自编 recovery。存在 LK boot 命令实现/加载限制或主机通信兼容性问题的可能，但没有 LK 日志，不能证明具体根因，也不能宣称命令一定未注册。设备最终回到原厂系统，没有报告分区被改写。

下一步先在原厂 recovery 未改写状态验证 `adb reboot bootloader` → `fastboot reboot recovery` 是否直接进入原厂 recovery。本地 fastboot 31.0.2 会发送 reboot-recovery，原机 lk.bin 有同名字符串，实际支持仍待测试。
只有该路径与关机 BROM 回退明确后，再安排仅独立 recovery 分区的刷入测试。不能刷后先 fastboot reboot 正常系统，再 adb reboot recovery：vendor 的 install-recovery.sh 可能先将自编 recovery 覆盖成原厂。若 reboot recovery 不支持，先另行落实进入路径；不以无根据的 OEM 命令或修改 LK 代替。

## 直接进入 recovery 路径已通过

用户确认 `adb reboot bootloader` → `fastboot reboot recovery` 能进入原厂 recovery。可以安排独立 recovery 分区刷入后直接进入的测试，不经过原厂系统。此结果不表示 fastboot flash 已验证，也不表示自编 recovery 已能启动。

按 384×854 实测屏幕准备窄屏文本。首次启用 `TARGET_RECOVERY_UI_SCREEN_WIDTH := 384` 触发固定 40px 字号生成器的空行异常（详见构建日志），因此取消该变量，改用设备私有 PNG：374px 可用宽度、18px 字号、保留所有语言。高度由 minui 从 framebuffer 读取。旧 artifacts/recovery.img 保留作历史测试版本，新镜像命名 recovery-384.img。

## 自编 recovery 实机启动通过

用户反馈：“跑起来了，显示 ok”。结合上一轮 recovery-384.img 刷入测试流程，记录自编 recovery 从独立分区启动、显示通过；确切刷入文件 SHA256 未由用户单独回报。
root ADB、SELinux 状态、分区访问、按键/触摸、fastbootd 和 FBE 解密仍待分别验证。不能从显示正常推断以上功能通过。
下一步收集 adb shell id、getenforce、USB 属性、by-name 分区列表与 recovery.log/dmesg；未做 wipe 或 ROM/zip 刷写。
