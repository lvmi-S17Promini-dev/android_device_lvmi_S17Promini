# 修复 GSI init 主动重启（r9 完整日志）

r9 已完成 policy load 并进入 early-init。7.596357 秒处理 /system_ext/etc/init/init.vndk-nodef.rc，7.597052 秒启动 /system/bin/reboot bootloader，7.618858 秒收到 sys.powerctl=reboot,bootloader，8.624997 秒进入重启。显示服务尚未启动。

lineage_S17Promini.mk 为兼容原厂 vendor 继承 gsi_release.mk，后者安装 init.gsi.rc 和 init.vndk-nodef.rc。init 会扫描 /system_ext/etc/init 的全部 rc；nodef 的 on early-init 是无条件 reboot，并非只有 ro.vndk.version 未定义才执行。日志已有 ro.vndk.version=31 的 import 展开，却缺 init.vndk-31.rc。此分支没有生成版本化 init.vndk-31.rc 的模块，不能随意补空文件来解决自动扫描到的 reboot guard。

init/service.cpp 的 ComputeContextFromExecutable 在 enforcing 下会拒绝缺域转换的 reboot 可执行文件，permissive 下只报警后继续。因此 r9 临时 permissive 激活了这段遗留的 GSI 重启行为，不能直接认定它就是 r7 enforcing 时卡屏的同一根因。

设备 Android.mk 把现有 init.s17promini-rom.rc 改为 ETC 预编译模块，使用构建系统原生 LOCAL_OVERRIDES_MODULES 替换 init.gsi.rc 和 init.vndk-nodef.rc；产品改为 PRODUCT_PACKAGES 安装该模块，目标仍为 /system/etc/init/init.s17promini-rom.rc，文件内容不变。保留 gsi_release.mk 其他兼容设置、skip_mount、VNDK 31/APEX，避免此次扩大布局变更。

增量输出中的两个旧 GSI rc 可能残留，生成 systemimage 前必须安装清理：m installclean；m -j8 systemimage。installclean 只清构建安装产物，不涉及设备 data/cache，也不清编译对象缓存。构建后确认 system/system_ext/etc/init 下没有 init.gsi.rc 和 init.vndk-nodef.rc，同时 system/etc/init/init.s17promini-rom.rc 存在且与源码一致。

该修复在 system 分区，单刷 boot 不会更新已经安装的 rc。可以继续用 r9 cachelog boot，刷新 system 后拉 cache early-kmsg 和 recovery.log。cpufreq 初始化旁路仍是临时状态，PPM 缺 DVFS table 的告警尚未修复。

验证：核对 build/make/core/base_rules.mk 对 ETC 支持 LOCAL_OVERRIDES_MODULES，以及 main.mk 的 module-overrides 过滤；host_init_verifier 和 git diff --check 通过。完整 systemimage 构建及实机测试交由用户进行，尚未完成。
