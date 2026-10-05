# r4 启动通过，自动 relabel 未生效

用户反馈：flash recovery-r4.img Sending/Writing OKAY，reboot recovery OKAY，设备可进入 recovery 并执行 root adb；is-userspace=yes，但 is-logical:system 仍 Partition not found，真实 super 节点仍为 block_device。

说明 r4 的持久化启动命令未达到预期，不能将该候选标记为完成。手工 chcon 的对照依然有效。

下一步先核对设备实际 /init.recovery.mt6765.rc 是否含 r4 命令，并获取 dmesg 的 exec/chcon/SELinux 相关日志。此镜像没有 logcat，之前请求 logcat 不适用，改用 dmesg。没有制作新的试刷版本。

本地代码复核：
- userdebug policy 确有 init → su process transition；不能直接断言缺少该 allow。
- ueventd MakeDevice 对已存在节点也可能执行 lsetfilecon，后续 uevent 有覆盖临时标签的可能，尚未实机确认。
- recovery init.rc 没有显式 coldboot 等待 action，时间顺序需实机日志验证。
- 其他候选：exec 没成功启动、命令执行时节点尚未建立、设备实际运行旧镜像。仅列排查点，不当作根因。

当前已验证的稳定基础仍为 recovery-384；r4 可启动但自动标签失败。无需因该问题恢复原厂或操作 super。需要查询 logical 分区时仍可手工 chcon 后从菜单进入 fastbootd（保持同次启动，不提前挂载 logical 分区）。
