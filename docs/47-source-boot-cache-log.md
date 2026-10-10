# 源内核启动失败日志恢复（r8）

恢复 2b9814e / 278094d 的早期 kmsg wrapper，并撤销 7a92b5b 的 on boot / stop console。正常 userdebug 的平台 init 已在 on init 启动 console，删掉后续 stop 即恢复原行为。串口 printk 参数另设 printk.disable_uart=0，不意味着设备有可接出的 UART。

新增 userdebug/eng 专用 init.s17promini-bootlog.rc，在 post-fs 开始两个 disabled/oneshot 服务：s17-boot-kmsg 读取 /dev/kmsg，每 250 ms 或 init/FATAL 记录 fsync，最多运行 300 秒；s17-boot-logcat 记录全部 logd 缓冲区，4 MiB×3 文件轮换。sys.boot_completed=1 停止两者。服务使用平台现有 userdebug su 域，未改变全局 SELinux enforcing 或增加 permissive 域；user 构建不安装这两个诊断服务。

日志：/cache/s17-early-kmsg.log（wrapper 的早期 30 秒）、/cache/s17-bootlog/kmsg.log、/cache/s17-bootlog/logcat.log 及轮换文件。wrapper 仍可能在 SELinux 切换后失去权限，post-fs 服务补充后续阶段；不能覆盖没有进入 /init 的内核阻塞。

rc 和采集器在 system 分区，更新 boot 不会更新 system rc。正常 out 构建 systemimage；r8 debug boot 以 r7 为输入，通过 make-debug-boot.py --input/--output/--work-dir 保留原 kernel、DTB、加载地址、cmdline 中 cpufreq blacklist，原 init 保存为 init.stock；只有 wrapper 被加入 ramdisk。

构建命令：m -j8 systemimage；python3 device/lvmi/S17Promini/tools/make-debug-boot.py --input /home/dengxh/S17Promini_LineageOS/artifacts/source-boot-r7/boot-source-r7-nocpufreq.img --output /home/dengxh/S17Promini_LineageOS/artifacts/source-boot-r8/boot-source-r8-cachelog.img --work-dir /home/dengxh/S17Promini_LineageOS/extracted/source-boot-r8-cachelog。

验证：host_init_verifier 对两个修改的 rc 通过；wrapper 静态 ARM32、无 PT_INTERP，源内核 CONFIG_COMPAT=y。boot 校验允许显式 collector-wrapper 模式，检查原 init 与全部原 ramdisk 条目保持内容/权限，只新增 wrapper 和 init.stock，校验源 kernel/DTB、加载地址、AVB 和 libufdt。

回 recovery 后先保存 /tmp/recovery.log；cache 未挂载时用 mount /cache，再拉两个日志路径。不 wipe data/cache。是否采集成功尚待实机确认。
