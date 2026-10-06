# S17Promini LineageOS 19.1 移植记录

阶段顺序：原厂镜像分析 → 预编译内核 recovery → 实机 fastboot boot / ADB 验证 → ROM → 非 A/B OTA zip。
当前 recovery 已编译并通过静态检查，`artifacts/recovery-r3.img` 已报告启动失败，停止使用；当前循环重启先通过 BROM 回写原厂 `stock_imgs/recovery.bin`；稳定后再用已验证的 `artifacts/recovery-384.img`，已通过启动/root ADB 实测的是 `artifacts/recovery-384.img`，旧 `artifacts/recovery.img` 保留。用户实测自编与原厂镜像均无法 fastboot boot，随后回到原厂系统；用户已确认 fastboot reboot recovery 能进入原厂 recovery，用户已反馈自编 recovery 从独立分区启动、显示正常；root ADB 与物理分区节点已验证，触摸无原始事件；fastbootd 的 super 标签问题正在处理。未进行分区刷写，自编 recovery 实机启动与显示已通过；root ADB、USB adb、SELinux Enforcing 已由日志验证；触摸不可用，fastbootd 已连接，但 logical system 查询失败；运行时 chcon 已确认 super 标签是 logical 查询失败的原因；r3 启动失败仍未定位，r4 以已验收基线持久化运行时命令。

- [原机与分区证据](01-stock.md)
- [移植步骤与问题](02-porting.md)
- [实机测试与日志](03-testing.md)
- [super 与 zip 方案](04-super-ota.md)

工作目录：`~/S17Promini_LineageOS`；设备树：`~/android3/lineage/device/lvmi/S17Promini`。
这两处 docs 内容同步；原始证据集中放工作目录 `extracted/metadata`。

- [无 Android 启动时的恢复入口](05-recovery-path.md)：按键未确认，先验证只读冷启动 mtkclient 接入，再继续实机测试。

- [实机信息与首次临时启动失败](06-device-test.md)

- [独立 recovery 刷入、取证与回退](07-flash-test.md)

- [Recovery 日志复核与下一步](08-recovery-log-review.md)

- [触摸输入事件复核](09-touch-input-review.md)：节点已注册，触摸时无事件；fastbootd 输出待补。

- [fastbootd 找不到 system 与 r3 修复](10-fastbootd-super.md)

- [SELinux 全局与域 permissive 的区别](11-selinux-options.md)
- [GSI 刷机记录参考价值与问题](12-gsi-reference-review.md)

- [r3 启动失败、差异审计与回退](13-r3-boot-regression.md)

- [原厂救回后的运行时 super 标签测试](14-runtime-super-test.md)

- [super 标签实机确认与 r4 控制变量](15-super-label-confirmed.md)

当前最小持久化候选：`artifacts/recovery-r4.img`，以已验收384为基线，仅 init RC 自动 chcon，构建/静态/init检查通过；实机可启动，但自动标签未生效，继续排查。r3保持停用。

- [r4 自动 relabel 未生效的排查](16-r4-relabel-review.md)

- [r5 super 标签服务与取证](17-r5-super-service.md)

当前稳定 recovery：r5，已实测自动标签status=ready、chcon成功、fastbootd识别logical system。

- [System-only 首次启动构建目标](18-system-bringup.md)

- [首次启动 SELinux genfscon 冲突](26-firstboot-genfscon.md)：cache 日志已定位，DT 使用预编译 vendor 策略兼容开关排除重复 fuseblk 标签。

2026-10-06：system-only LineageOS 19.1 首次成功启动进入系统，用户确认扬声器、相机、Wi-Fi 正常。对应 DT 提交 `4fe5fad`；暂保留当前可启动镜像作为后续调试基线。

- [Vendor blob 清单与后续清理](27-vendor-blobs.md)：完整原厂文件/符号链接清单已生成，预装 APK 已列出；仅记录，尚未清理或构建 vendor。补充实测蓝牙、麦克风、充电、按键唤醒、Doze 正常，recovery 触摸暂缓。

- [Vendor 预装 APK 清理](28-vendor-apk-pruning.md)：删除 6 个应用及专用库/预优化文件，保留 15 个资源 overlay；手机端待后续 vendor 镜像刷入。

- [移除 recovery 恢复组件](29-disable-recovery-restore.md)：删掉服务、脚本及 patch 文件；原厂未实际恢复的用户观察保留。

- [尽早开启免授权 ADB](30-early-debug-adb.md)：调试产品 ro.adb.secure=0，post-fs 请求启动 adbd，并处理旧 USB-off 持久值；需重建 system 实测。

- [清理版 prebuilt vendor 构建](31-prebuilt-vendor-build.md)：原镜像重打包，保留 stock 元数据/HAL/策略，接入 m vendorimage；待实机测试。

清理版 vendor 实机通过：刷入后清空 data，成功开机、无原厂预装应用、功能测试正常。保留该镜像作为后续逐文件 vendor 构建的对照基线。

- [展开 vendor blob 与按文件构建](32-expanded-vendor.md)：proprietary/vendor 文件树及 stock 元数据已导出，新 ext4 从文件构建；完整内容/权限/标签/链接验证通过，待实机测试。

展开 blob 重建的 vendor 已实机通过：用户确认 RIL、Wi-Fi、相机、声音、蓝牙全部正常。基线 vendor-expanded-r1-validated；下一阶段处理正常 boot 和非 A/B 动态分区安装 zip。

- [正常 boot 与调试 ADB](33-normal-boot.md)：无 collector，stock kernel/DTB/ramdisk 对照通过；待实机启动。
- [首版全量安装 zip](34-full-install-zip.md)：m s17-installzip，原厂 LP 布局上更新 system/vendor/boot/vbmeta/r5 recovery；构建通过，待 sideload 验证。
