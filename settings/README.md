# S17Promini 电源方案

入口：设置 → 电池 → 电源方案。提供省电、平衡、高性能，默认平衡。
选择保存在 `persist.sys.s17.power_profile`，init 在属性变化和开机完成时应用。

| 方案 | cluster 0 / policy0 上限 | cluster 1 / policy4 上限 |
| --- | --- | --- |
| 省电 | 1617 MHz | 1226 MHz |
| 平衡 | 2009 MHz | 1491 MHz |
| 高性能 | 解除本功能上限（硬件最高 2301 MHz） | 解除本功能上限（硬件最高 1800 MHz） |

频率来自 2026-10-11 本机源码内核日志的 OPP 表；这是初始配置，续航及流畅度需实机测量。
本机 cluster 0 是快核，cluster 1 是慢核，不能照搬常见的大小核编号。

UI 参考 nabu 的实现：
- https://github.com/celeron633/android_device_xiaomi_nabu/commit/ebee7180f2adf96a02f3d3200b974e8c78801e11
- https://github.com/celeron633/android_device_xiaomi_nabu/commit/92c36cd21a429c963050effb27600b5e930ebf7b

S17Promini 使用原厂 MTK Power HAL，没有 nabu 的 IPowerExt / libperfmgr 后端。
这里由 init 写 `/proc/ppm/policy/hard_userlimit_max_cpu_freq`，格式为
`cluster_id max_kHz`，依次更新两个 cluster。最低频率不变；高性能给两个
cluster 的上限写 -1，撤销本功能的最高频率请求。
保留原厂 HAL 使用的 hard_userlimit_cpu_freq 节点标签和权限。
USER_LIMIT 的原厂 boost 请求继续使用原有路径，PPM 仍合并温控和功率预算限制；
不改变 governor、核心数或 GPU 配置，也不修改系统省电模式。
如果后续原厂服务也写 HARD_USER_LIMIT，可能覆盖这里的请求，需要实机验证。

应用采用平台签名、独立 UID 和专用 `s17_devicesettings_app` 域，只有该域可设置
本功能的属性。与 nabu 修复的原则一致，授权实际运行域；该域是 coredomain，
因此属性使用 system_internal_prop。入口要求 DEVICE_POWER 权限，设置应用可访问。
仅限频节点使用专用 proc 标签并授权 init 写入，UI 没有 proc/sysfs 写权限。

构建（LineageOS 源码根目录）：

```sh
source build/envsetup.sh
lunch lineage_S17Promini-userdebug
m -j4 S17DeviceSettings system_ext_sepolicy.cil \
    out/target/product/S17Promini/system/system_ext/etc/selinux/system_ext_seapp_contexts \
    out/target/product/S17Promini/system/system_ext/etc/selinux/system_ext_property_contexts \
    out/target/product/S17Promini/system/etc/init/init.s17-power-profiles.rc
```

需要重新构建并刷入包含应用、init rc 和策略的 system 镜像，单独安装 APK 不够。
刷机后依次切换三个档位，再重启确认保存状态。检查：

```sh
adb shell getprop persist.sys.s17.power_profile
adb shell cat /proc/ppm/policy/hard_userlimit_max_cpu_freq
adb shell cat /proc/ppm/dump_policy_list
adb shell ps -AZ | grep com.lvmi.s17settings
adb logcat -d -s S17PowerProfiles init
```

节点输出为频率索引，不是 kHz。当前 OPP 表中省电对应 cluster 0 索引 9、
cluster 1 索引 6，平衡对应 4、3，高性能对应 -1、-1。
CPU 实际频率还受负载和温度影响；观察 HARD_USER_LIMIT 和 Final limit，
不能仅凭 UI 选择或 scaling_cur_freq 判断是否正确应用。
系统省电开关、休眠恢复及高负载温控也需一起验证。

## 本轮验证

- S17DeviceSettings APK、system_ext_sepolicy.cil、应用域/属性上下文及 init rc 构建通过。
- 构建中的 SELinux neverallow 检查通过；host_init_verifier 检查通过。
- XML 解析通过，四个限频值均存在于本机记录的 CPU OPP 表。
- 新 system_ext 策略与原厂 vendor CIL 按 Android 启动时的 `secilc -N` 合并方式编译通过，未出现 genfscon 冲突。
- 对整套原厂 vendor CIL 额外开启严格 neverallow 检查会遇到 stock/Lineage 的兼容冲突（例如 llkd ptrace、su binder、原厂 system_app 权限）；不表示这套预编译 vendor 已通过全部源码策略审计。本轮未修改这些原厂策略或关闭构建的 neverallow 检查。
- 未构建完整 system.img、未刷机。入口显示、模式切换、重启持久化及 HAL 是否覆盖请求仍需实机验证。
