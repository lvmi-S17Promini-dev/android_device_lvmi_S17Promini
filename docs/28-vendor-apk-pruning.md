# Vendor 预装 APK 清理（2026-10-06）

用户要求删除不必要 APK。已检查 APK manifest、dex 和 vendor 文本配置引用，清理以下 6 个应用的完整目录，并从 DT proprietary-files.txt 删除对应条目。

| 删除目录 | 文件数 | 总大小 |
| --- | ---: | ---: |
| `vendor/app/ExactCalculator` | 1 | 0.6 MiB |
| `vendor/app/MtkBrowserExt` | 1 | 4.6 MiB |
| `vendor/app/TikTokLiteCN` | 3 | 394.2 MiB |
| `vendor/app/WeatherHitqMini` | 3 | 25.6 MiB |
| `vendor/app/doudoubirdCalendar` | 3 | 51.5 MiB |
| `vendor/operator/app/QQMusic` | 161 | 362.4 MiB |

共移除 172 个文件，约 838.9 MiB；包括 APK、QQ 音乐专用 native 库和各应用 oat/odex/vdex。当前清单剩 1878 个普通文件，188 个原有符号链接未改。

原因：抖音、QQ 音乐、第三方天气/日历均不承担硬件 HAL 功能；Lineage common_mobile 已提供 Etar、ExactCalculator、Jelly，可替代原厂日历、计算器和浏览器。MtkBrowserExt 含 classes.dex 和完整浏览器组件，是 com.android.browser 的应用，不是硬件资源 overlay。对 vendor/etc、vendor/odm、vendor/operator 文本配置搜索上述应用的包名/目录名，未发现引用；未改公共库、HAL、firmware 或策略。

剩余 15 个 APK 均在 manifest 中声明 overlay，针对 framework、Settings、SystemUI、Phone、CellBroadcast、Wi-Fi、NetworkStack 和 Tethering，当前保留。Google 或 inprocess 目标在本次系统上是否启用，留到后续 overlay 实机核对；仅凭文件名不删除它们。

删除已作用于 `~/S17Promini_LineageOS/extracted/filesystems/vendor` 工作目录和 DT blob 清单。stock_imgs 原始备份未改；当前手机和现有 vendor.img 未改，必须在后续生成并刷入清理后的 vendor 镜像才会从设备上消失。新解包时按本页排除上述完整目录，避免重新纳入。

验证：清单剩余路径与工作目录所有普通文件逐项一致，确认仅删除选定目录，剩 15 个 overlay APK。未构建或刷写；extract-files/setup-makefiles 和 vendor 构建接线仍待下一步完成。
