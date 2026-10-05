# r3 启动失败报告与回退（2026-10-05）

用户反馈 recovery-r3 启动不了，重启进入原厂系统。完整 flash/reboot 输出、是否短暂出现 recovery 待补；当前按启动回归处理，停止使用 r3，不操作 super/vbmeta。

## 回退已验证版本

```powershell
adb reboot bootloader
fastboot flash recovery .\recovery-384.img
fastboot reboot recovery
```

确认 Sending/Writing 成功；直接进入 recovery，避免原厂 Android 覆盖恢复镜像。recovery-384.img 的 SHA256 为 8845c801b93b0f5f795d37f761f95f2a5c0b5a702957a209612576c7ec773004，已实测启动、显示、root ADB。

## 离线差异审计

三个镜像分别完整解包到 extracted/regression-r3，逐文件内容/链接/权限比较：
- recovery-384 → r2：仅增加五张确认界面文字 PNG。
- r2 → r3：仅 vendor_file_contexts 增加 by-name/super、mmcblk0p32 两条 super_block_device 标签。
- 三个镜像 kernel/DTB/内嵌 recovery DTBO 均逐字节相同。
- r2/r3 init 二进制、init rc、fstab、compiled sepolicy、其他资源逐字节相同。
- r3 ramdisk gzip 比 r2 多 46 bytes；加载地址、页大小、DTB/DTBO 偏移均一致，镜像总大小均21635072。

差异列表：extracted/regression-r3/recovery-384-vs-recovery-r2.json、recovery-r2-vs-recovery-r3.json。
不能把失败直接解释为 kernel 或新增策略规则导致，因为这些组件没有变化。两条标签是候选变化，但未经异常日志确认，不能断言其导致重启。也不能把静态检查通过等同于可启动。

## 待确认/取证

- 实际使用 flash recovery 还是 boot；后者此前对 stock/custom 已证实不可用。
- 完整 Sending/Writing/Rebooting 输出，实际文件名和 Windows Get-FileHash；不能假定写入已成功。
- 当前设备是否曾经过正常 Android，被 vendor install-recovery.sh 覆盖 recovery。
- 回到已验证 recovery 后读取上次启动持久日志：

```powershell
adb pull /sys/fs/pstore .\r3-pstore
adb shell ls -lZ /dev/block/mmcblk0p32
```

pstore 可能为空或在多次重启后被覆盖，空目录不能证明没有崩溃。暂不通过反复刷未知镜像排障。

## 后续更小的权限对照

可在已验证 recovery 内先检查真实 super 标签，再临时 chcon 到 super_block_device，通过菜单 Advanced → Enter fastboot 在同一次启动中切换，然后做 getvar 查询。源码 recovery_main.cpp 表明未映射 logical partitions 时该菜单可以不重启切换；若已映射，会重启，临时标签会消失。仅在恢复稳定后安排，不替代本轮启动回归取证。本轮未运行 chcon，也未生成新试刷版本。

设备树与 r3 制品保留供审计；r3 不再列为可刷候选。当前源码仍包含调查中的两条标签，独立重编译不表示已解决该失败。

## 用户补充：刷写成功，启动前重启/循环

```text
fastboot flash recovery .\recovery-r3.img
Sending recovery (21128 KB) OKAY [0.558s]
Writing recovery OKAY [0.286s]
fastboot reboot recovery
Rebooting into recovery OKAY
```

用户确认没有出现 recovery 界面就重启，进 Android 后再 adb reboot recovery 也失败，随后持续重启，准备先恢复。写入失败不再是首要假设，r3 启动回归已确认；仍未获取崩溃日志，具体根因未确定。

优先经已确认 BROM 接入方式只回写本机原厂 stock_imgs/recovery.bin，使设备恢复稳定；不全盘恢复、不写 super/boot/vbmeta/GPT/LK/preloader。原厂恢复后再安排从已验证 recovery-384 提取 pstore。当前已停止 r3 试刷。

## 恢复结果

用户已反馈原厂恢复成功。下一步从已验收 recovery-384 做运行时标签对照和取证，详见 14-runtime-super-test.md。r2 未单独验收，不能排除新增资源相关回归，因此对照基线使用384，不再把r2当作已知可启动。
