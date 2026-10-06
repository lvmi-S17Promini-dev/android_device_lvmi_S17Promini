# 接入 Lineage 关机充电（2026-10-06）

原厂 system 的 kpoc_charger 链路在 Lineage system 中缺失，现有 `/system/bin/charger` 没有对应启动服务。按用户要求，在 `rootdir/init.s17promini-rom.rc` 中新增 `service charger /system/bin/charger`，属于 `class charger`。平台 `on charger` 的 `class_start charger` 自动启动该服务，无需重复触发 late-init/post-fs 或正常 Android 启动流程。

服务以 root 运行，组为 root/system/wakelock/input/graphics；能力 SYS_BOOT、SYS_TTY_CONFIG、BLOCK_SUSPEND 支持电源操作、显示终端及 wakelock，日志使用 `/dev/kmsg`。现有 charger_exec 标签及 init 到 charger 的 SELinux 转换保持；无 critical/oneshot/disabled，故不因服务启动失败而强制重启，退出时由 init 正常重启服务。

复用当前 Lineage charger 程序及动画资源；保留 vendor 的 health HAL、fuelgauge 和 charger 初始化。r1 没有新增 charger ADB；后续 r2 已接入独立充电调试服务，见 [充电模式独立 ADB](43-charger-debug-adb.md)。

构建：`lunch lineage_S17Promini-userdebug` 后 `m -j8 systemimage vbmetaimage`。该 RC 位于 system，单独刷 boot 不会生效。

验证完成：host_init_verifier 使用 platform/vendor property contexts 校验通过；构建成功；输出 RC 与源码一致，charger 的直接共享库依赖和 charger_exec 文件标签存在；git diff --check 通过。测试产物导出到 `~/S17Promini_LineageOS/artifacts/rom-charger-r1/`，包含 system.img、vbmeta.img 和 SHA256 清单 build.json。新 vbmeta flags=3。尚未刷机或验证关机充电。

实机测试建议：在现有 recovery 进入 fastbootd，确认 `fastboot getvar is-userspace` 返回 yes，刷本次 system.img；沿用当前 flags=3 的 disabled vbmeta。正常启动确认后，拔 USB、彻底关机、再插电。检查电池动画/电量、短按电源亮屏、长按电源正常启动、拔线退出。充电动画出现不等于上述行为全部通过。

```powershell
adb reboot fastboot
fastboot getvar is-userspace
fastboot flash system .\system.img
fastboot reboot
```

如果仍停留 orange state，用 41 文档的无 ADB 取证方案检查 charger 是否启动、health HAL 是否就绪，以及 charger 的显示/sysfs AVC。当前接入未改变 MTK KPOC 内核行为，不把 RC 静态通过当成关机充电实机验收。
