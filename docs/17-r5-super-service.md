# r5：可观察的 super 标签服务（2026-10-06）

r4 的设备脚本内容已核对，包含 exec/chcon，排除运行旧 RC。新增 early dmesg 从0.99秒开始，包含 first-stage/second-stage、vendor_init 读取 rootfs bin 的 AVC、cmode 写入 AVC，以及ueventd启动；没有捕获明确的 chcon/exec 退出错误。不能据此把某条 AVC 当作已证实的唯一根因。
原始日志 recovery-debug/recovery-r4-early-dmesg.txt 为 UTF-16，归一化和提取事件在 normalized。

## 改动

- 删除 r4 的匿名 on boot exec。
- 新增 disabled/oneshot 命名服务 s17-super-label，执行 shell helper，使用已在运行的 recovery 域（该域本来为 permissive），不新增 SELinux 规则。
- boot 时异步 start，避免等待阻塞 recovery 启动。
- helper 等待 ro.cold_boot_done=true 与真实 super 节点，最多10秒；ueventd上游确实在冷启动完成后设置此属性。
- 进入 fastbootd 的 sys.usb.config=fastboot trigger 再 exec_start，一次性重新设置标签，防止启动期间后续设备事件覆盖。
- 日志 /tmp/s17-super-label.log 记录时间、id、前后标签、chcon退出码；vendor.recovery.super_label.status 为 waiting/ready/failed。
- 不写分区、不改内核/DTB/DTBO/compiled sepolicy，不合入r2新增图片。

此候选解决了时序与可观察性薄弱的问题，但r4究竟未执行、执行失败还是标签被重置，尚未由日志证明；r5需要实机验收。

## 实机流程

```powershell
adb reboot bootloader
fastboot flash recovery .\recovery-r5.img
fastboot reboot recovery
adb shell getprop init.svc.s17-super-label
adb shell getprop vendor.recovery.super_label.status
adb shell cat /tmp/s17-super-label.log
adb shell ls -lZ /dev/block/mmcblk0p32
adb reboot fastboot
fastboot getvar is-userspace
fastboot getvar is-logical:system
fastboot getvar partition-size:system
```

Sending/Writing均成功再继续。oneshot执行完服务状态stopped为正常，status应ready；若没有日志文件，服务启动/执行本身就需排查，不再把无输出误认为成功。
如果失败，回 recovery 后保存 helper 日志（重启可能清空 /tmp）和 dmesg；可在切fastbootd前先 adb pull 日志。不要手工chcon后把结果误记为自动标签验收。

## 构建与审计

r5 编译成功（57秒），init RC 和脚本语法检查通过，完整解包静态检查通过。
镜像 `artifacts/recovery-r5.img`，20840448 bytes，SHA256 `5a2801235d740ff6d02aae0bd17c5e775e3984bf2b5900a985afa312aa827e43`。
与已验收384的文件内容/链接/权限比较，只修改 init.recovery.mt6765.rc，新增 system/bin/s17-super-label.sh；kernel、DTB/DTBO、compiled sepolicy、vendor_file_contexts和资源均保持基线。审计清单 `extracted/metadata/recovery-384-vs-r5.json`。实机效果待验证。

## 实机验收通过

用户实测 r5：status=ready；日志时间1.67s，helper为uid=0、context=u:r:recovery:s0；真实super从block_device改为super_block_device，chcon exit=0；进入fastbootd后is-logical:system=yes。未手工chcon，自动修复验收通过。

稳定 recovery 更新为 r5。r3启动回归仍未定位，保持停用。触摸和data解密不在本次修复内；logical分区实际刷写和完整ROM仍需分别验收。
