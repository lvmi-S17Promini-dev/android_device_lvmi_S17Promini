# Recovery 日志复核（2026-10-05）

> 2026-10-11 更新：用户确认 OSS 内核 recovery 触摸已修复；下文保留当时的 prebuilt/测试状态。旧自动固件刷写失败的补充说明见 [修复确认](95-recovery-touch-fixed.md)。

输入：`recovery-debug/misc.txt`、`recovery.log`、`recovery-dmesg.txt`。保留原文件，归一化与摘要放 `recovery-debug/normalized/`。PowerShell 导出的 dmesg 是 UTF-16 LE；直接 rg 会漏掉匹配，因此先转换 UTF-8。

## 已验收

- ADB 显示 recovery，`id` 为 uid=0/gid=0，context=u:r:su:s0。
- SELinux Enforcing；USB configfs=1、controller=musb-hdrc、state=adb、ffs.ready=1。
- fbdev framebuffer 384×854；LineageOS 19.1 属性和本机私有 zh-CN 文本已加载。
- /cache ext4 挂载成功；by-name 物理分区节点建立，符合 GPT。
- 分区节点可见不等于已验证所有分区可读写；logical 映射和 fastbootd 尚未实测。

## 问题

| 项目 | 证据与处理 |
|---|---|
| 五个确认界面位图缺失 | cancel_wipe_data/factory_data_reset/try_again/wipe_data_confirmation/wipe_data_menu_header 缺失。补齐全部多语言窄屏 PNG，构建 r2 镜像；不通过执行 wipe 来验收 |
| data 无法挂载 | Invalid ext4 superblock。原厂 fstab 有 metadata keydirectory，可能是尚未建立解密映射；不能诊断成数据损坏，不格式化 |
| AXS firmware update 失败 | 5794 行 dmesg 中 4667 行 AXS，其中 4610 行 flash write waiting；后续 sector 写入结束，read firmware not same with writed firmware，升级失败，16.8s 工作结束 |
| 触摸不可用 | 用户确认只能按键。AXS 固件校验失败是候选原因，须结合 getevent 检查有没有触摸坐标/接触事件，不能直接认定 UI 或驱动哪一方损坏 |
| charger SELinux AVC | 20 行 charger 读取 sysfs:type 被拒绝，tcontext=sysfs。先获取实际节点路径，再精确标记，不增加 charger 对整个 sysfs 的宽泛读权限，也不切 permissive |
| DRM、virtual keys 信息 | DRM 设备不存在后成功使用 fbdev，是可接受 fallback；virtualkeys 文件不存在不能单独证明触摸驱动未工作 |

日志开头的 bootonce-bootloader 为 BCB 信息，与 ro.boot.mode=recovery/Lineage recovery 实际运行并不矛盾。日志系统时间来自设备，落在 2025-09-16，并非当前构建时间；不要按设备时钟判断日志版本。recovery 的 ro.vendor.build/ro.vndk.version=32 来自 recovery 构建环境，不代表 stock vendor 已升级；原厂 vendor 仍为 VNDK31。

## 下一步只读取证

在当前 recovery 先获取触摸信息：

```powershell
adb shell getevent -lp > recovery-input-devices.txt
adb shell getevent -lt > recovery-touch-events.txt
```

第二条运行时触摸屏幕数秒，不按可能选中危险菜单的按键，再 Ctrl+C。记录有没有 event/ABS_MT_POSITION_X/Y/BTN_TOUCH/TRACKING_ID。保留原文件供解析。

随后验证 fastbootd，不刷任何 logical 分区：

```powershell
adb reboot fastboot
fastboot getvar is-userspace
fastboot getvar is-logical:system
fastboot getvar partition-size:system
fastboot getvar partition-size:vendor
fastboot reboot recovery
```

is-userspace 应为 yes，is-logical:system 应为 yes；若进入失败，保留屏幕现象/输出并回 recovery 取 logcat/recovery.log。read-only 查询通过后再推进 ROM 的 vendor 保留、fstab/AVB 和动态分区安装。

如需后续修 charger 标签，在 recovery 收集 `adb shell ls -lZ /sys/class/power_supply` 和各条目链接的真实路径，不执行 sysfs 写入。


## r2 构建结果

`artifacts/recovery-r2.img`：21635072 bytes，SHA256 `1125a174f2414f2c39ff8fd576425444ca63489aa314f6e9740bb91c5fbb6ee4`。补齐五张缺失确认界面文字，10 张私有资源打包和尺寸检查通过；构建成功（1 分钟）。未改变 kernel、DTB/DTBO、USB、fstab 或 SELinux 策略；不包含触摸/data/charger 修复。旧实测镜像保留，r2 尚未实机验证，当前不要求立即重刷以便先取输入事件和 fastbootd 日志。
