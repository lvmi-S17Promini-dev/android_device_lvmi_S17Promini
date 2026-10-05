# 首次启动日志：先试 LK 的 printk 开关（2026-10-06）

空vbmeta对照仍在Orange State后黑屏，重启进入bootloader。当前没有新内核失败日志，不能确定根因。
原厂kernel：PSTORE_RAM/CONSOLE=y、MTK_AEE_IPANIC=y、MTK_DRAM_LOG_STORE=y；PRINTK缓冲512KiB。pstore重复旧内容，是否真正更新仍待验证。
原厂boot ramdisk的init字符串未发现init_fatal_panic/first_stage_console，因此不能保证直接追加AOSP新debug参数对第一阶段有效；recovery init是动态链接，不能简单替换boot中的静态init。

LK二进制包含oem p2u、printk.disable_uart=0/1。公开MTK sys_commands.c中p2u on在continue时应用到内核命令行；只是开启printk到UART，不保证本机pstore后端随之更新。先做无需刷写的试验：

```powershell
fastboot oem p2u on
fastboot continue
```

不要用reboot替代continue，运行时参数可能丢失。若失败后回到fastboot，再进入r5抓前次日志：

```powershell
fastboot reboot recovery
adb pull /sys/fs/pstore .\lineage-pstore-printk
adb pull /proc/last_kmsg .\lineage-last-kmsg.txt
```

last_kmsg是否存在未验证，不存在则保留pstore。若OEM命令拒绝或仍只有旧日志，再准备debug boot或查MTK log_store/AEE入口；不直接向未知ramoops内存地址写入。

来源：https://github.com/l33tnoob/lk_mtk/blob/master/bootable/bootloader/lk/app/mt_boot/sys_commands.c 。不是本机完整源码，仅结合本机字符串提出测试。
