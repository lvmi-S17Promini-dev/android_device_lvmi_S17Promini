# 触摸输入采集复核（2026-10-05）

用户确认执行 getevent -lt 后触摸数秒，文件已放 recovery-debug。原始导出为 UTF-16，已转换 UTF-8 存入 normalized，原件保留。

## 结果

- `/dev/input/event3` 名称 axs_ts，声明 BTN_TOUCH、ABS_MT_POSITION_X/Y、ABS_MT_TRACKING_ID、压力，坐标范围 0..384 / 0..854，INPUT_PROP_DIRECT。
- `/dev/input/event4` 名称 mtk-tpd，声明触摸、多点坐标与 BTN_TOUCH，范围同上。
- recovery-touch-events.txt 只有五个设备的枚举文本，**没有一条实时输入事件**。
- 用户已确认触摸不能操作 recovery，只有实体按键可用。

## 判断边界

节点和 capability 表明输入设备已注册，不代表硬件正常上报。此次没有原始坐标/接触事件，优先排查 AXS 驱动、IRQ、固件/休眠状态；不能靠旋转坐标或改菜单命中区域解决。
前次 dmesg 的触摸固件更新读回校验失败是相关证据，但还不能证明唯一根因。
检查本地 getevent.c：stdout 使用 setbuf(stdout,NULL)，采集不依赖退出时 flush；minui/recovery_ui 无 EVIOCGRAB 调用，因此未发现 recovery 独占输入导致 getevent 看不到的代码证据。

没有改动 prebuilt kernel 或主动操作触摸固件更新/reset/sysfs 写入，避免未知接口造成进一步故障。触摸暂不阻塞实体按键和 ADB 的 recovery 刷机路径。

## 后续

当前未找到 fastbootd 测试输出，不将其记录为已通过。先确认 is-userspace=yes、is-logical:system=yes 与 logical partition sizes，再进入 ROM 动态分区准备。
如深入触摸：收集 /proc/bus/input/devices、/proc/interrupts（触摸前后对比）、event3/event4 的 sysfs 实际路径和早期启动 dmesg，确认 IRQ 是否变化及驱动工作状态；不盲写 firmware/debug/reset 节点。
