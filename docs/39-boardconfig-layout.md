# BoardConfig 分组整理（2026-10-06）

用户指出配置与常见 Lineage DT 相比缺少分类；先不进行 vendor 模块迁移，本轮只整理配置结构。参考 marlon 的 Architecture/Bootloader/Display/Kernel/Partitions/Recovery/Verified Boot 功能分组。

BoardConfig.mk 保留公共架构、平台、显示、prebuilt kernel/DTB、分区、文件系统、recovery 和独立 recovery 的 AVB 默认。正式 ROM 条件仍为 TARGET_PRODUCT=lineage_S17Promini，改为 include BoardConfigRom.mk。

BoardConfigRom.mk 单独管理 SELinux/VINTF、ROM 分区与路径、VNDK/metadata/audio、vendor blobs、OTA、AVB、stock boot ramdisk 和生成 recovery 的 mkbootimg 参数。删掉过期的 r3 bring-up 注释，未改变原配置值或生效条件。

验证：两目标分别对重排前后所有原 BoardConfig 赋值变量及 BOARD_PREBUILT_VENDORIMAGE 做构建系统 dumpvars 比较，逐字一致；ROM/recovery 均通过解析，git diff --check 通过。本轮未构建镜像，无需重刷。验证输出保存在工作目录 extracted/metadata，未提交 Git。
