# Vendor blob 清单与后续清理（2026-10-06）

下一阶段改为整理原厂 vendor；本轮仅列清单，不删文件、不构建、不刷写。recovery 触摸暂缓。

来源：`~/S17Promini_LineageOS/extracted/filesystems/vendor`，原始 stock vendor 镜像解包目录。odm 嵌在 vendor 中，已纳入。

- DT `proprietary-files.txt`：2050 个普通文件，按 vendor 顶层目录分类，使用 Lineage 常见的分区相对路径格式。这是未筛减的原厂基线，不是最终构建输入；含 build.prop、预编译策略、原厂 recovery 恢复组件、应用和预优化文件，后续分别替换或剔除。
- DT `proprietary-symlinks.txt`：188 个符号链接及原目标，单独记录，避免将链接误复制为重复库。此文件为参考格式，不直接喂给 extract-utils。
- 尚未生成 vendor/lvmi 提取脚本和 Android.mk/Android.bp，当前可启动 system-only 配置继续复用原厂 vendor。

## 原厂 APK

共 21 个，包名由本机 aapt 读取；清理候选按用途和目录初筛。网络、Framework、Wi-Fi 等资源 overlay 先保留，后续确认对应系统组件兼容性。

| 原厂路径 | 包名 | 初步处理 |
| --- | --- | --- |
| `vendor/app/ExactCalculator/ExactCalculator.apk` | `com.android.calculator2` | 应用候选 |
| `vendor/app/GoogleNetworkStackResOverlay/GoogleNetworkStackResOverlay.apk` | `com.google.android.networkstack.overlay` | 资源 overlay，先保留 |
| `vendor/app/GoogleTetheringResOverlay/GoogleTetheringResOverlay.apk` | `com.google.android.networkstack.tethering.overlay` | 资源 overlay，先保留 |
| `vendor/app/InProcessTetheringResOverlay/InProcessTetheringResOverlay.apk` | `com.android.networkstack.tethering.inprocess.overlay` | 资源 overlay，先保留 |
| `vendor/app/MtkBrowserExt/MtkBrowserExt.apk` | `com.android.browser` | 浏览器扩展待确认 |
| `vendor/app/NetworkStackInProcessResOverlay/NetworkStackInProcessResOverlay.apk` | `com.android.networkstack.inprocess.overlay` | 资源 overlay，先保留 |
| `vendor/app/NetworkStackResOverlay/NetworkStackResOverlay.apk` | `com.android.networkstack.overlay` | 资源 overlay，先保留 |
| `vendor/app/TetheringResOverlay/TetheringResOverlay.apk` | `com.android.networkstack.tethering.overlay` | 资源 overlay，先保留 |
| `vendor/app/TikTokLiteCN/TikTokLiteCN.apk` | `com.ss.android.ugc.aweme.lite` | 应用候选 |
| `vendor/app/WeatherHitqMini/WeatherHitqMini.apk` | `com.coo.weather` | 应用候选 |
| `vendor/app/doudoubirdCalendar/doudoubirdCalendar.apk` | `com.doudoubird.calendar` | 应用候选 |
| `vendor/operator/app/QQMusic/QQMusic.apk` | `com.tencent.qqmusic` | 应用候选 |
| `vendor/overlay/CellbroadcastUIResOverlay/CellbroadcastUIResOverlay.apk` | `com.mediatek.cellbroadcastuiresoverlay` | 资源 overlay，先保留 |
| `vendor/overlay/FrameworkResOverlay/FrameworkResOverlay.apk` | `com.mediatek.frameworkresoverlay` | 资源 overlay，先保留 |
| `vendor/overlay/FrameworkResOverlayExt/FrameworkResOverlayExt.apk` | `com.mediatek.FrameworkResOverlayExt` | 资源 overlay，先保留 |
| `vendor/overlay/MtkSettingsResOverlay/MtkSettingsResOverlay.apk` | `com.mediatek.MtkSettingsResOverlay` | 资源 overlay，先保留 |
| `vendor/overlay/MtkTelephonyServiceResOverlay/MtkTelephonyServiceResOverlay.apk` | `com.mediatek.MtkTelephonyServiceResOverlay` | 资源 overlay，先保留 |
| `vendor/overlay/SettingsProviderResOverlay/SettingsProviderResOverlay.apk` | `com.mediatek.SettingsProviderResOverlay` | 资源 overlay，先保留 |
| `vendor/overlay/SystemUIResOverlay/SystemUIResOverlay.apk` | `com.mediatek.systemuiresoverlay` | 资源 overlay，先保留 |
| `vendor/overlay/WifiResMainlineOverlay/WifiResMainlineOverlay.apk` | `com.android.wifi.mainline.resources.overlay` | 资源 overlay，先保留 |
| `vendor/overlay/WifiResOverlay/WifiResOverlay.apk` | `com.android.wifi.resources.overlay` | 资源 overlay，先保留 |

清理应用时连同所在目录的专用 lib/oat/odex 一起处理，并核对 vendor 配置对包名的引用；当前未执行删除。HAL、firmware、公共 32/64 位库先保留，再逐项区分可由源码构建的部分。

恢复工作时：先从上述完整基线筛出最终 proprietary-files，生成 extract-files/setup-makefiles 和 vendor 构建配置，再构建 vendor 镜像实机验证。保留 SELinux fuseblk 冲突修复及原厂必要的 MTK 策略。
