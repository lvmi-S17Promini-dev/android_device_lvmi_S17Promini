# 充电模式独立 ADB 与 SELinux 核对（2026-10-06）

按用户要求，给 Lineage charger 增加免授权 root USB ADB。只在 `lineage_S17Promini` 的 userdebug/eng 产品打包，普通 user 产品和独立 recovery 产品不接入本服务。

## 启动方式

Android 12 的原 adbd 服务是 updatable，正常启动后由 com.android.adbd APEX 覆盖。charger 模式没有 post-fs-data/APEX 激活流程，bootstrap APEX 列表也没有 com.android.adbd。因此单加 `start adbd` 无法解决。

设备 Android.mk 将本次源码构建的 `adbd.recovery` 输出重新打包为 `/system/bin/s17-charger-adbd`，并打包其需要的 `libadb_protos.recovery` 为 `/system/lib64/libadb_protos.so`。依赖编译产物，没有复制固定二进制进设备树。其他动态库使用现有 system 库；构建的 ELF 检查校验 SONAME、DT_NEEDED 及符号兼容性。

新增 `init.s17promini-charger-adb.rc`：

- 在 init 阶段为 charger 模式准备 FunctionFS 目录和 ffs.adb function，原厂 vendor 在 on charger 中负责挂载 FunctionFS。
- 原厂 charger USB 会先选择 HID。等待 sys.usb.state=hid 后选择 none，等待平台 teardown 完成的 sys.usb.state=none 后配置 musb-hdrc、MTK VID/PID、AIO compatibility，选择 adb 并启动独立服务。
- 平台已有 USB RC 在 sys.usb.ffs.ready=1 后将 ffs.adb 连接到 gadget 并绑定 UDC。原 adbd 的启动请求仍会等待 APEX；充电期间提供连接的是独立服务。
- 默认 service.adb.root=1，沿用当前产品 ro.adb.secure=0；不依赖 /data 上的授权 key。banner 使用 host ADB 支持的 device 值，通过 ro.bootmode 和独立服务状态识别 charger。
- 服务属于 class charger，USB 切到 none 时停止；从 charger 继续到 late-init 时停止并将 service.adb.root 恢复为 0。正常冷启动使用原有 APEX adbd。

如果 init 卡在 charger USB 初始化之前的同步 fsck，或更早的策略加载阶段，本服务也可能无法起来；它不替代早期 kmsg collector。

## SELinux 的处理范围

上一版 charger RC 复用了平台的 charger_exec 标签、init→charger 转换和 charger 权限，没有新增 allow，也没有完成实机 AVC 验证。

本次通过 SYSTEM_EXT_PRIVATE_SEPOLICY_DIRS 接入设备私有 file_contexts，将 `/system/bin/s17-charger-adbd` 标为 adbd_exec。服务以 adbd 域启动，复用已有 FunctionFS、属性和 shell 转换权限。root 调试使用平台 userdebug 已有 su 域行为；该域原本为 permissive。没有新增 permissive 声明，没有全局关闭 SELinux，charger 仍保持 Enforcing。

已核对原厂 vendor CIL：真实 mt6357-gauge/power_supply 和 mt6357-charger-type-detection/power_supply 路径已有 sysfs_batteryinfo 标签。旧 recovery 日志中的 charger 读取 generic sysfs/type 被拒绝，不能自动当成当前 ROM 的同一节点问题；缺少这些拒绝节点的完整路径。没有给 charger 增加整个 sysfs 的读权限。当前 chargermode 是否还有显示/电池 AVC，仍需实机日志确认。

## 验证与产物

`m -j8 systemimage vbmetaimage` 完成。host_init_verifier 使用 platform/vendor property contexts 校验 RC 通过；ELF 依赖和符号检查、构建的 SELinux 检查通过；输出 RC 与源码一致。使用 Android init 同样的 secilc 参数（包括运行时惯用的 -N）将新 platform/system_ext、31.0 mapping 和原厂 vendor CIL 合并成功。这验证运行时策略可合并，不宣称混合版本 vendor 的全部 neverallow 校验通过；未设置 SELINUX_IGNORE_NEVERALLOWS。

产物：`~/S17Promini_LineageOS/artifacts/rom-charger-adb-r2/`，包含 system.img、vbmeta.img 及 build.json SHA256 清单。未刷机，charger USB 枚举和充电行为待实测。

沿用当前 flags=3 的 disabled vbmeta，在 fastbootd 中仅刷新的 system.img，正常开机确认后完全关机再插 USB 测试。

```powershell
adb reboot fastboot
fastboot getvar is-userspace
# 确认 is-userspace=yes
fastboot flash system .\system.img
fastboot reboot
```

充电模式连接后：

```powershell
adb devices -l
adb shell id
adb shell getenforce
adb shell getprop ro.bootmode
adb shell getprop init.svc.s17-charger-adbd
adb shell getprop init.svc.charger
adb shell getprop sys.usb.state
adb shell dmesg > .\charger-dmesg.txt
adb logcat -b all -d > .\charger-logcat.txt
adb shell 'for p in /sys/class/power_supply/*; do echo "$p"; readlink -f "$p"; ls -ldZ "$p/"; ls -lZ "$p/type"; done' > .\charger-power-supply.txt
```

期望 uid=0、getenforce=Enforcing、ro.bootmode=charger、独立 adbd 和 charger 为 running、sys.usb.state=adb。即使画面仍停留在 orange state，也先取上述日志；AVC 修复应结合真实路径和标签。随后测试充电动画/电量、电源键和拔线退出，并确认正常开机后的 ADB 仍可用。
