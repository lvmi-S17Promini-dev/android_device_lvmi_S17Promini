# 救回原厂后的下一步：已验证 recovery 上运行时标签对照

用户已确认通过恢复原厂 recovery 救回设备。停止 r3，先不刷 ROM/super/vbmeta。

## 原因与边界

r3 刷写/重启命令成功，但在出现 UI 前重启。r2 从未单独做启动验收，不能仅凭 r2/r3 只有 file_contexts 不同，就认定启动问题一定由标签引起：已验收的 recovery-384 与 r3 之间还增加了五张图片。
离线比对未发现 kernel/DTB/DTBO、init 或 compiled sepolicy 变化。检查 ramdisk：stock 未压缩23841536，384=23515136，r3=24331776；压缩 r3=10483187，镜像21635072 <32MiB。没有证实具体 LK 加载限制，不能拿这些大小直接诊断根因。

先在已验收 recovery-384 上验证标签假设，不把它写入 ramdisk/file_contexts，不做持久更改。

## 1. 回到已验收 recovery

Windows 当前目录放 recovery-384.img，核对 SHA256 为 8845c801b93b0f5f795d37f761f95f2a5c0b5a702957a209612576c7ec773004。

```powershell
adb reboot bootloader
fastboot flash recovery .\recovery-384.img
fastboot reboot recovery
adb shell id
```

Sending/Writing 均 OKAY 才继续，应 uid=0。只使用已验收镜像；不刷 r2/r3。

## 2. 先取可能的上次异常日志和当前标签

```powershell
adb pull /sys/fs/pstore .\r3-pstore
adb shell ls -lZ /dev/block/mmcblk0p32
```

pstore 可能为空或已被恢复/多次重启覆盖，保留输出即可。

## 3. 运行时改真实节点标签

```powershell
adb shell chcon u:object_r:super_block_device:s0 /dev/block/mmcblk0p32
adb shell ls -lZ /dev/block/mmcblk0p32
```

只改 /dev 中设备节点的内存标签，不写 super 内容；重启会丢失。不修改 sysfs 触摸固件、策略全局模式或分区布局。若 chcon 失败，保存报错，不继续下一步。

## 4. 不重启地进入 fastbootd

在 recovery 中用音量键/电源键选择 Advanced → Enter fastboot；不选 Mount/unmount system，不使用 adb reboot fastboot。

本地 recovery_main.cpp：ENTER_FASTBOOT 在 logical_partitions_mapped=false 时设置 fastboot=true，继续同一进程循环，保持同一内核及 /dev 标签；已映射 logical 分区时会改用 Reboot(fastboot)，这会丢掉临时标签。因此使用刚启动的 recovery，先不挂载 system/vendor。

若菜单提示需要重启或实际发生重启，记录现象，本次运行时标签对照无效，不能将后续失败作为 chcon 无效的证据。

## 5. 只读查询

```powershell
fastboot getvar is-userspace
fastboot getvar is-logical:system
fastboot getvar partition-size:system
fastboot getvar partition-size:vendor
```

预期 is-userspace=yes、is-logical:system=yes，可读出大小。不要执行 flash/erase/resize/delete-logical。
成功将确认普通标签权限为关键原因，下一步再用最小镜像差异处理持久化；失败则需读取 metadata/槽位和日志，不直接拼 super 或放宽全部域。

当前仅制定流程，未执行实机 chcon/取证，没有新的试刷镜像。
