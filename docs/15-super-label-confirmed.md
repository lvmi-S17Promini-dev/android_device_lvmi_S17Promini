# super 标签问题实机确认与最小持久化候选

## 用户实机结果

```text
/dev/block/mmcblk0p32: u:object_r:block_device:s0
chcon u:object_r:super_block_device:s0 /dev/block/mmcblk0p32
/dev/block/mmcblk0p32: u:object_r:super_block_device:s0
is-userspace: yes
is-logical:system: yes
partition-size:system: 0xB694B000
```

0xB694B000 = 3063197696，与 stock super 的 system LP 大小一致。通过同一次启动中的节点标签干预，确认查询失败的原因是 generic block_device 标签与 fastbootd 权限不匹配。不是 system 消失、LP 表损坏，也无需关闭全局 Enforcing。
用户操作只修改 /dev 内存标签，没有修改 super 内容或分区布局。此结论不证明已经验证刷写 logical 分区，更不解释 r3 为什么启动失败。

## pstore 结果

recovery-debug/r3-pstore/console-ramoops-0 共262132 bytes，覆盖339.0～477.5秒。里面出现 system_server、fuelgauged、vendor init，最后 reboot,bootloader；这是原厂 Android 的前一次运行记录，没有保留 r3 早期启动失败。可保留为证据，但无法据它确定 r3 根因。
摘要 recovery-debug/normalized/pstore-analysis.json。里面也有触摸驱动调用栈，不能将其直接归为 r3 崩溃。

## r4 的控制变量

以已验收 recovery-384 为基线：
- 五张新增确认界面资源移出默认 recovery/res，暂存 recovery/res-extra；r2/r3 原镜像保留。
- 不纳入 r3 的 vendor file_contexts，文件保留供调查。
- 仅在 init.recovery.mt6765.rc 的 on boot 中自动执行用户刚验证成功的 chcon 命令。
- 命令使用已有 userdebug init→su 转换权限，su 域本来已 permissive；不新增 policy、permissive domain 或 kernel patch。
- 所有内核/DTB/DTBO、fstab、USB、启动地址仍沿用已验收基线。

```text
exec u:r:su:s0 root root -- /system/bin/chcon u:object_r:super_block_device:s0 /dev/block/mmcblk0p32
```

init 在 on boot 执行命令，只有 /dev 标签变化，不写磁盘。每次启动（包括启动进 fastbootd）都尝试设置专用标签，不再依赖手工 chcon。命令执行若失败，应保留 init 报错；不把错误忽略成已经修复。

r4 仍需实机启动验收，不能声称 r3 根因已经定位。对发布 ROM 的最终方案仍应采用正确的设备标签与 policy；运行时 chcon 是当前 bring-up workaround。

## 再生成文字资源

tools/generate-recovery-text.py 默认只生成已验收的五张基本资源。`--full` 会生成包含确认界面的完整资源到 recovery/res-extra/images，不自动合入默认镜像。待启动回归定位后再验证那些资源。

## r4 构建与审计

构建成功（2 分 7 秒），init RC 经 host_init_verifier 检查通过。
镜像 `artifacts/recovery-r4.img`，20840448 bytes，SHA256 `f34022e912a7f3c64273e6acbf33c97a328d6d4fbe75e734451b83ead7865fed`。
解包后逐文件内容、链接与权限对比 recovery-384：**只有 init.recovery.mt6765.rc 改变**；compiled sepolicy、vendor_file_contexts、所有资源及二进制都与已验收基线一致。差异清单 `extracted/metadata/recovery-384-vs-r4.json`。
内核/DTB/DTBO 和加载地址检查通过。尚未实机启动，不把此结果解释成已经修复 r3 根因。

复验路径：从当前 fastbootd 用 fastboot reboot bootloader，然后 flash recovery-r4.img → reboot recovery；检查 id 和真实 super 标签，接着 adb reboot fastboot，再查 is-logical:system 与 size，验证新一次启动也能自动设置标签。无需手工 chcon，也不依赖同次内核生命周期。

## r4 实机结果

启动与 root ADB 可用，但节点仍为 block_device，logical 查询仍失败。自动exec未达到预期，原因待设备RC与dmesg定位。手工标签对照结论不变；见16文档。
