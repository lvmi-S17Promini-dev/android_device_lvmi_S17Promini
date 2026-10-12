# 电池耗电归因估算表（2026-10-12）

设置长期显示“没有电池使用数据”的一个直接原因是默认功耗表：Settings 的 BatteryAppListPreferenceController 只有在 `screen.full.display0 >= 10 mA` 时才添加耗电列表。当前默认值为 0.1，原厂 framework/vendor/product 三份表的屏幕值也都是 0.1。

按用户要求，用公开同平台参数建立初始估算表。没有本机功耗实测，显示的分项耗电比例有误差；此表用于恢复耗电归因，不改变硬件频率或充放电行为。

## 来源和选择

- [三星 MT6765 JDM P35 参数表](https://github.com/Samsung-Galaxy-G85-JDM/android_device_samsung_mt6765-jdm/blob/e7c6079b0dca5c2b9409a21517db857797dc5e6c/overlay/FrameworksResOverlay_JDM_P35/res/xml/power_profile.xml)：采用 CPU 的 core_speeds/core_power、cpu.active、cpu.idle、cpu.suspend、cluster_power；其 4+4 核、32 个频点与本机采样完全匹配。
- [小米 Play / lotus 参数表](https://github.com/xiaomi-lotus-devs/android_device_xiaomi_lotus_old/blob/5e805fbdcec9253f2c3b6a821b0eb317180d2613/overlay/frameworks/base/core/res/res/xml/power_profile.xml)：作为 P35 对照，快核频点匹配，但使用旧 cpu.speeds/cpu.active.cluster 字段，慢核有 460 MHz 而本机为 501 MHz，未直接采用其 CPU 功耗。
- [小米 Redmi 6 / cereus 参数表](https://github.com/xiaomi-mt6765/android_device_xiaomi_cereus/blob/da11465329d2ce986d7e91c7d5c1167c5d0ec297/overlay/frameworks/base/core/res/res/xml/power_profile.xml)：用于屏幕与 Wi-Fi、蓝牙、音视频、相机、GPS、移动网络的初始估算。该机是 MT6762/P22，属于相关 MT6765 平台，但 CPU 参数未用于本机。
- Redmi 9A / dandelion 的公开设备表也有大量 0.1 占位值；RMX1941 的公开表为 6+2 核配置；OPPO CPH1909 的公开表频点和功耗数组长度不同。均未选作本机 CPU 表。

## 本机适配

配置位于 `overlay/S17PowerProfileOverlay/res/xml/power_profile.xml`。

- Cluster 0 是 cpu0-3，900–2301 MHz；cluster 1 是 cpu4-7，400–1800 MHz。频点和电流按本机日志 `/proc/uid_time_in_state` 的升序排列，不按 scaling_available_frequencies 的降序照抄。两组各 16 档，逐项与三星 P35 表匹配。
- 使用 Android 12 的 `cpu.core_speeds.clusterN`、`cpu.core_power.clusterN` 和 `screen.*.display0` 字段；音视频改为 `audio` / `video`。
- 屏幕以用户提供的约 4 寸 LCD、已确认的 384×854 分辨率为依据，对 cereus 5.45 寸、720×1440 LCD 进行面积比例估算（约 0.49）：69/212 mA 折算并取整为 screen.on=35、screen.full=105 mA。面积折算没有考虑亮度、面板和驱动效率差异，属于近似值。screen.full 表示满亮度增加的背光电流，满亮度显示模型约为 140 mA。
- 不为 LCD 设置 AOD 耗电，ambient.on.display0=0。
- battery.capacity=3000 mAh 是 fallback 估算；现有日志报告的 learned capacity 约 2946 mAh，BatteryChargeCalculator 优先使用有效 learned capacity。
- 清理参考表的重复字段和旧 CPU 字段，未采用没有校准的 modem/GPS controller 参数，使用活动时间模型。

## 接入与覆盖优先级

`lineage_S17Promini.mk` 安装 `S17PowerProfileOverlay`。它是平台签名的 product static RRO，只覆盖 android 的 `xml/power_profile`。

原厂 vendor FrameworkResOverlay 的 priority=1，FrameworkResOverlayExt 为 2。新表的 priority=999，在当前无 overlay 配置文件的按 priority 排序模式下优先；若按分区配置排序，product 也晚于 vendor。没有移除包含其他硬件参数的原厂覆盖包。

这里使用 RRO 而非仅在 framework-res 中加入编译时 XML：原厂 vendor RRO 会整体替换该 XML，单改 framework-res 可能仍被占位表覆盖。

## 验证与构建

本轮完成源码 XML、唯一键、数值、Settings 阈值和 CPU 数组验证。全部 32 个频点按顺序与工作目录 `oss-kernel-debug/power-debug/s17-power-before/dumpsys-batterystats.txt` 的 `CPU freqs` 完全一致。

按用户要求，停止已启动的模块验证构建，构建与刷机由用户执行；没有声称 APK 或完整 ROM 构建通过。

```bash
source build/envsetup.sh
lunch lineage_S17Promini-userdebug
m -j4 S17PowerProfileOverlay
# 按平时的目标构建包含此 product overlay 的 system 镜像或安装包。
```

刷入后重启，检查：

```bash
adb shell cmd overlay list --user 0 android
adb shell dumpsys overlay com.lvmi.s17.overlay.powerprofile
adb shell cmd overlay lookup --verbose android android:xml/power_profile
adb shell dumpsys batterystats --charged
```

确认新包启用且资源路径来自 S17PowerProfileOverlay。新 XML 不在 framework-res.apk 内，单独解包 framework-res 不能验证最终生效的表。

拔线正常使用，待真实下降几个百分点后再检查列表。Settings 会过滤四舍五入不足 1% 的条目，所以刚充满或无实际放电时仍可能显示没有数据。若没有恢复，收集 dumpsys battery、batterystats、overlay 和 BatteryStats/OverlayManager 相关 logcat；当前无连接的 ADB 设备，未进行实机验证。

## 用户构建产物复核（2026-10-12）

- `system/product/overlay/S17PowerProfileOverlay.apk` 已生成。aapt2 解码后的全部 32 个配置项与源码一致，包含 35/105 mA 屏幕参数和两组各 16 档 CPU 参数。
- 编译后 manifest 是 static RRO，targetPackage=android、priority=999，包名为 com.lvmi.s17.overlay.powerprofile。
- apksigner 校验覆盖 APK 和 framework-res.apk 均通过，两者证书 SHA256 相同：`c8a2e9bccf597c2fb6dc66bee293fc13f2fc47ec77bc6b2b0d52c11f51192ab8`。
- 从 `lineage-19.1-20261012-UNOFFICIAL-S17Promini.zip` 的 system.new.dat.br 和 transfer list 还原文件系统，提取 `/product/overlay/S17PowerProfileOverlay.apk`，与新构建 APK 逐字节一致，SHA256 为 `332afeb566d0d4c6c6605e067afdfe2ebd66281ec0893eed26034a20415bb9b1`。最新安装 ZIP 确实包含修复。
- 输出根目录的独立 system.img 时间仍为 2026-10-11 02:18；本轮验证的是上述安装 ZIP，不应把该旧镜像视为这次的新系统产物。
- ADB 当前没有设备；运行时启用状态和实际耗电列表仍待刷机后检查。
