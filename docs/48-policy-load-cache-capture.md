# 策略加载后 cache 采集继续（r9）

r8 early-kmsg 明确显示 cpufreq init blacklisted、内核初始化完成、system/vendor 挂载并进入 init。文件恰在 Loading SELinux policy 后停止，尚不能证明显示逻辑阻塞。

fork 的早期 collector 仍处在 kernel 域，平台策略不允许它持续读取 kmsg 和写 cache。为不刷 system 的取证场景，make-debug-boot.py 新增显式 --permissive 和 --tag；默认不追加 permissive 参数。此模式使用 enforcing=0 和 androidboot.selinux=permissive，前者覆盖 policy 首次加载的时间窗，后者供 Lineage userdebug 的 init 使用。采集器窗口扩大到 120 秒，仍不改变原 init 的 PID1 身份。

关键：原 S17 源内核 CONFIG_SECURITY_SELINUX_DEVELOP 未启用，enforcing=0 会被忽略，/sys/fs/selinux/enforce 也不能切换。因此测试 fragment 必须启用 CONFIG_SECURITY_SELINUX_DEVELOP=y，然后重编译 source boot，不能仅重新打包 r7 kernel。正常 init 未指定 permissive 时仍要求 enforcing；原设备 defconfig 未变。

r9 build 保留 S17_SKIP_CPUFREQ_INIT=true，kernel 版本 r9-cachelog。先生成原 ramdisk 的 source boot，再以它为 --input 制作 wrapper boot，使用 --tag r9 --permissive。这是临时采集镜像，不能据“能在 permissive 下启动”认定 SELinux 拒绝就是全部根因；须检查新日志和 recovery reason。

静态验证必须核对最终 .config 的 SELINUX_DEVELOP、cmdline 两个参数、cpufreq blacklist、r9 tag、原 init/ramdisk 内容、源 kernel/DTB、AVB 和 libufdt。最终是否能继续采集尚待实机确认。正常 DT 的 system 不必重刷。
