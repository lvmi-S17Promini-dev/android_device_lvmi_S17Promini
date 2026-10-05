# Debug boot：早期 kmsg 写入 cache（2026-10-06）

p2u on试验后pstore仍逐字节等于旧记录。停止重复该后端，做独立日志采集。

boot-kmsg-debug.img 保留stock kernel/DTB/fstab/属性，将stock init逐字节保留为/init.stock；新增静态ARM32 PID1 wrapper（内核COMPAT=y），fork短期采集器后exec原init，原init仍是PID1。collector等原init挂好/mnt及cache块设备就绪，读取/dev/kmsg，写/cache/s17-early-kmsg.log；不格式化cache，不写system/vendor/userdata。使用32MiB boot大小和有效NONE AVB footer，要求当前disabled vbmeta。

限制：主要捕获第一阶段；加载SELinux策略后collector可能失去读写权限而停止。cache额外挂载可能影响后续cache检查，因此只作诊断；这不是已验证的生产boot，尚未实机测试。pstore无更新不证明没有进入内核。

重建：`python3 device/lvmi/S17Promini/tools/make-debug-boot.py`，使用现有arm-linux-musleabi-cross工具链，无需ROM/内核重编译。
静态检查：stock init、kernel、DTB逐字节一致；newc结构检查通过；wrapper静态ARM32，Kernel COMPAT已确认。
镜像33554432 bytes；SHA256 d749476602be41e49d7370d029df6d2fb7dae6c36ff62ccf94ccaf4447e270c6。

```powershell
fastboot flash boot .\boot-kmsg-debug.img
fastboot reboot
```

失败回到bootloader后：

```powershell
fastboot reboot recovery
adb pull /cache/s17-early-kmsg.log .\lineage-early-kmsg.log
```

不要先Format data/wipe cache，日志会被清掉。若文件不存在，可能没有进入wrapper、collector不能挂载cache或执行失败；不要据此自动断言是哪一种。
取完日志可恢复本机原始stock_imgs/boot.bin，不动LK或recovery：`fastboot flash boot .\boot-stock.bin`（按键进入bootloader执行）。
