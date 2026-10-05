# fastbootd 找不到 logical system：分析与 r3（2026-10-05）

用户实机输出：

```text
is-userspace: yes
getvar:is-logical:system FAILED (remote: 'Partition not found')
getvar:partition-size:system FAILED (remote: 'Could not open partition')
```

## 分层判断

fastbootd 的 USB/进程已工作，但 logical partition 查询未通过。不能把 Partition not found 理解为原厂 super 已丢失 system。
本地 utility.cpp：LogicalPartitionExists 先 FindPhysicalPartition(super)，后 ReadMetadata(super,slot)，后按名称查找。FindPhysicalPartition 用 access(path,W_OK)；若 SELinux 拒绝对节点的访问，会返回 false，最终产生上述消息，甚至尚未读取 LP metadata。

备份 LP metadata 已成功用 in-tree lpunpack 解包，包含 system/vendor/product。设备非 A/B，SlotNumberForSlotSuffix(空字符串)=0；fs_mgr_get_super_partition_name 默认 super。当前 recovery packaged file_contexts 没有 super 标签，原厂 vendor_file_contexts 有该标签。
AOSP public/fastbootd.te 允许 super_block_device_type 块设备读写，而 public/domain.te 禁止 fastbootd 直接读写泛型 block_device。因此缺失标签是有明确代码依据的首要假设；尚未获得故障现场 AVC/ls-Z，不能声称已经完全确认根因。

## r3 实现

新增 device/lvmi/S17Promini/sepolicy/vendor/file_contexts，纳入 BOARD_VENDOR_SEPOLICY_DIRS：

```text
/dev/block/by-name/super u:object_r:super_block_device:s0
/dev/block/mmcblk0p32    u:object_r:super_block_device:s0
```

mmcblk0p32 由 GPT 与用户 by-name 列表两份证据确认。ueventd 初始化时应给真实块节点设置专用标签；fastbootd 使用已有平台 allow 规则，不增加通用块设备权限。
继承 r2 的文字资源补全；不改 super 元数据、fstab、触摸驱动、boot、LK 或 vbmeta。

## 用户提出关闭 Enforcing

用户允许 bring-up 阶段关闭 Enforcing。原厂内核 CONFIG_SECURITY_SELINUX_DEVELOP/BOOTPARAM/DISABLE 均未启用，常规 setenforce 0 或 androidboot.selinux=permissive 无法切全局 permissive。本轮不修改二进制内核，优先修标签。这个结论不等于任何二进制补丁都不可能，而是常规切换不受原厂内核支持。

## 实机复验（候选镜像构建/静态检查通过后）

```powershell
adb reboot bootloader
fastboot flash recovery .\recovery-r3.img
fastboot reboot recovery
adb shell ls -lZ /dev/block/mmcblk0p32
adb reboot fastboot
fastboot getvar is-userspace
fastboot getvar is-logical:system
fastboot getvar partition-size:system
fastboot getvar partition-size:vendor
fastboot reboot recovery
```

Sending/Writing 都成功才继续。真实 super 节点预期 super_block_device，is-userspace=yes、is-logical:system=yes。仅查询，不刷 super/逻辑分区。
若仍失败，保存 fastbootd 模式的完整 logcat/AVC 与 super 名称/槽位查询结果，进一步区分标签、metadata slot、geometry/CRC、dm 建图等问题。不因查询错误擦除或重建 super。

## 构建与静态复验

r3 编译成功（1 分 57 秒），大小 21635072 bytes。
产物 `artifacts/recovery-r3.img`，SHA256 `d1d99bc83ad2407c865e77de19f571b824a753c17d1f007e037777cfc55af71d`。
解包复验通过：kernel/DTB/内嵌 DTBO、加载地址与 stock 一致；super 两条规则存在于镜像内 vendor_file_contexts；编译后的 sepolicy 的 super_block_device_type 属性包含 super_block_device。
未增加 allow/permissive 规则；沿用平台 fastbootd 的 super 权限。实机标签与 logical partition 查询仍待复验。

若当前手机仍在 fastbootd，可直接 `fastboot reboot bootloader`，再 flash recovery-r3.img 和 reboot recovery，不必先启动 Android。

## 实机回归报告

用户反馈 r3 启动失败并回到系统。暂停使用 r3，回退 recovery-384.img，按 13-r3-boot-regression.md 取证；缺失标签仍是假设，尚未获得修复成功证据。
