# ROM recovery 改为源码生成（2026-10-06）

> 2026-10-11 更新：用户确认 OSS 内核 recovery 触摸已修复；下文保留当时的 prebuilt/测试状态。旧自动固件刷写失败的补充说明见 [修复确认](95-recovery-touch-fixed.md)。

按用户要求，正式 ROM 不再固定 prebuilt r5 recovery。删除 BOARD_PREBUILT_RECOVERYIMAGE 和 DT 的 prebuilt/recovery.img；原 r5 仅在工作目录 artifacts 中作为历史基线保存。正式目标和独立 recovery 目标都使用 in-tree recovery 构建。

正常 boot 仍使用已验证 stock first-stage ramdisk；为避免 BOARD_MKBOOTIMG_ARGS 的 --ramdisk stock 参数覆盖 recovery，ROM 单独设置 BOARD_RECOVERY_MKBOOTIMG_ARGS，仅包含 header/offset/DTB/OS/SPL，recovery 的 ramdisk 由源码生成。内核继续 prebuilt。

build/make 补丁删除全部 prebuilt recovery 分支及 target-files 拷贝支持，剩余改动用于 vendor 文件树、fs_config、block map 以及设备 releasetools 依赖。setup-makefiles.sh 应用缩减后的补丁。历史自定义打包工具也改为读取 PRODUCT_OUT/recovery.img，不依赖 r5 blob。

软件检查：生成 recovery 的 kernel/DTB 与 stock 一致，ramdisk 与 normal boot stock ramdisk 不同；包含 system/bin/recovery、init.recovery.mt6765.rc、s17-super-label.sh、recovery.fstab 和窄屏文字 PNG，init RC 与 super relabel 脚本和当前 DT 内容一致。正式 recovery 按 AVB 设置生成 32MiB 镜像；独立 recovery 产品沿用 AVB=false。

正式命令不变：lunch lineage_S17Promini-userdebug; m -j8 bacon。源码生成 recovery 尚未实机启动验证；用户上一版正式包已实测正常，原包保留作为对照。本轮不修改 vendor blob 或要求重做保留 data/清 data 两条安装测试。

验证：m -j8 bacon 成功；target-files/OTA 使用源码生成的 recovery，OTA 的 recovery 与 target-files 镜像完全一致，kernel/DTB 和 recovery 可执行文件/init/super label/fstab/UI 与原生构建对照通过。完整签名检查通过。生成物在 artifacts/rom-generated-recovery，recovery SHA256 5d068406de3f86a98a70ac6d906fd57708f1d2b6d5a16ba538a86c80e85e159d，OTA SHA256 d303be0055da747c535d0b60b53d76e5a37989cf725d6dc868813eba0331f45d。框架提交 e5d5038e3 删除 prebuilt recovery 支持。实机启动待用户验证。

实机验收：用户确认本轮源码生成 recovery 测试正常。标记 generated-recovery-validated，正式 ROM 使用源码生成 recovery 的方案已通过恢复环境实测。未额外推断本轮整包重刷或 recovery 触摸测试；触摸仍按先前要求暂缓。
