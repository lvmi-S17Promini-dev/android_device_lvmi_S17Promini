# 无 Android 启动时的回退入口（待实机验证）

用户已确认：只有按键无法进入 fastboot/recovery，adb reboot 可用。BROM 接入方法是完全关机、同时按住音量 + 和音量 −、插 USB；此前用这个入口成功解锁与备份。当前不刷任何分区，优先 RAM 临时启动。

## 已有证据

- 用户此前用 mtkclient 成功解锁并读取分区，说明曾存在可用的底层访问链路，且已提供独立于 Android 的关机按键接入方法；本轮未连接设备复测，恢复写入未验证。
- 原厂 lk.bin 包含 boot-recovery、boot-fastboot、cmd_boot、boot menu key 等字符串，只能证明相关代码/文本存在，不能证明按键组合或入口实际可用。
- 主机有 ~/mtkclient，commit cd25cf9c1ff6d36e82697ac2c798e69e9cfb78c3。使用此前成功的 Python 环境、驱动、线缆和接入方式，避免改变条件。
- stock_imgs 没有 preloader/完整 eMMC boot1、boot2 备份。普通 GPT 分区读取不包含这些硬件区域；不能称已有备份覆盖所有启动区域。

## 先做只读冷启动验证

1. 在设备正常时先准备好 mtkclient，完全关机；不要依赖 adb reboot 来接入。
2. 按此前成功的连接方式接入 BROM/preloader，运行 printgpt；记录完整日志、连接方法以及日志中的实际模式。
3. 再读取 recovery 到一个新文件，与已有 recovery.bin 比较 SHA256，证明冷启动链路能读出正确数据。
4. 设备恢复正常启动后，重复一次。此步骤仅验证读取，不能据此声称已经验证写入恢复。
5. 用户已提供独立于 Android 的 BROM 接入方法；如果无法重复接入，再排查强制复位、驱动和线缆。

命令语法（在之前已成功的 mtkclient 环境执行，首次测试不要执行 w/e/wf 等写入或擦除命令）：

```bash
cd ~/mtkclient
python mtk.py printgpt
python mtk.py r recovery /home/dengxh/S17Promini_LineageOS/artifacts/recovery-coldboot-readback.bin
sha256sum /home/dengxh/S17Promini_LineageOS/stock_imgs/recovery.bin /home/dengxh/S17Promini_LineageOS/artifacts/recovery-coldboot-readback.bin
```

## 回退策略

初期仅测试 RAM 中 fastboot boot 的 recovery。它不主动写分区，但运行中的 recovery 本身可访问并写存储；只做启动与日志验证，不进行安装/格式化。
若后续必须刷 recovery，则以能冷启动进入 mtkclient 为前提，失败时回写原厂 recovery.bin；只回写被改的分区，不重刷全部备份。
仅 boot/recovery 损坏一般不会改坏 SoC BootROM 和未被写入的 preloader；本机实际能否通过该路径恢复仍取决于强制复位、USB 接入、认证和 DA 条件，不能保证永远可救。
GPT、preloader/boot1/boot2、lk/lk2、seccfg、NVRAM 和 RPMB 不纳入第一阶段改写。
preloader/boot1/boot2 补备份需要另行确认实际存储类型、工具支持和读取范围；未完成。保存此前成功的工具环境和 DA/loader 文件。

依据：[mtkclient 官方使用说明](https://github.com/bkerler/mtkclient/blob/main/README-USAGE.md)。只读验证尚未执行，未连接设备，未执行回写。

## 仅 recovery 损坏时的回写命令（备用，未执行）

进入 BROM 后，在此前成功的 mtkclient 环境执行：

```bash
cd ~/mtkclient
python mtk.py w recovery /home/dengxh/S17Promini_LineageOS/stock_imgs/recovery.bin
```

这个命令只针对 recovery；正常测试时不要执行。需要确认工具识别的是本机、备份 SHA256 正确，写入完成后按工具提示复位。若设备卡死无法关机，先解决强制复位，不以能 adb reboot 为回退前提。

## fastboot boot 支持情况：未确认

不能按 MT6765 型号或已解锁状态保证 fastboot boot 可用。2026-10-05 静态查看原厂 lk.bin，可找到 `cmd_boot,boot_hdr = NULL`、`incomplete bootimage` 等字符串，说明包含相关处理代码的迹象；也有 `not support on security`、`not allowed in locked state`。字符串不能证明命令已注册、运行时允许或镜像能成功加载。

公开的 MTK LK 实现中，命令是否注册和安全策略参数受构建条件影响：
https://github.com/dguidipc/gemini-lk/blob/master/lk/app/mt_boot/fastboot.c
该源码不是本机源码，不能据此确认本机支持。此前将 fastboot boot 当作可用路径的表述应理解为待验证候选路径。

可先在 bootloader fastboot 用备份的原厂 recovery.bin 做临时启动基线测试。`unknown command` 表示命令不支持；`not support on security` 表示被安全策略限制；镜像格式/地址错误说明需进一步检查加载实现。`Sending` 成功不能证明 `Booting` 成功；进入原厂 recovery 才完成基线验收。getvar all 不能单独证明支持 boot。
若不支持，不修改 LK 绕过；在回退条件明确后再安排仅 recovery 分区的持久化测试。未执行任何实机命令或刷写。
