# 首次启动：SELinux genfscon 冲突（2026-10-06）

`lineage-debug/cache/s17-early-kmsg.log` 已抓到失败启动：stock 内核和 init 正常运行，system/vendor 挂载成功；约 3.95 秒 secilc 报 `Problems processing genfscon rules`，随后 `Unable to open SELinux policy`、`InitFatalReboot: signal 6`。当前阻塞是策略编译，不是未进入内核。

主机 secilc 使用当前构建的 platform/system_ext、31.0 mapping 和原厂 vendor CIL 复现：vendor_sepolicy.cil 第 9 行将 `fuseblk /` 标为 `fuseblk`，system_ext_sepolicy.cil 第 1 行将同一路径标为 `vfat`。移除后者后合并编译返回 0。

system-only BoardConfig 设置 `TARGET_USES_PREBUILT_VENDOR_SEPOLICY := true` 和 `TARGET_HAS_FUSEBLK_SEPOLICY_ON_VENDOR := true`，由 Lineage 自带配置排除重复规则。保留原厂 vendor 策略；无需关闭 Enforcing。

重新构建：

```sh
cd ~/android3/lineage
source build/envsetup.sh
lunch lineage_S17Promini_system-userdebug
m -j8 systemimage vbmetaimage
```

在已验证的 r5 recovery 中用 `adb reboot fastboot` 进入 fastbootd，确认 `fastboot getvar is-userspace` 为 yes 后刷新的 system.img，再 `fastboot reboot`。沿用当前禁用验证的 vbmeta 和 boot-kmsg-debug，失败可再次提取 cache 日志。不要重新清空 data/cache。

日志读取注意：collector 独立挂载缓存分区后会卸载。recovery 下若 `/cache` 未挂载，先执行 `mount -t ext4 /dev/block/by-name/cache /cache`；若 shell 原先位于 `/cache`，先 `cd /`，再用绝对路径 `ls /cache`，避免继续列出挂载前目录。

验证：`m -j4 system_ext_sepolicy.cil` 成功；使用实际新生成的 system_ext CIL 与原厂 vendor CIL 进行主机 secilc 合并返回 0。完整 system.img 未重新构建，待用户构建及实机启动验证。

实机结果：用户重新构建刷入后成功开机并进入 LineageOS 系统；扬声器、相机、Wi-Fi 首轮测试正常。此次 genfscon 修复已通过实机启动验证；其他功能、生产 boot 和 OTA 尚待后续验证。
