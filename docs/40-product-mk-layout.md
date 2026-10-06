# 产品 makefile 格式整理（2026-10-06）

按用户要求整理 lineage_S17Promini.mk、lineage_S17Promini_recovery.mk、common.mk、device.mk：统一继承配置、产品标识、API、VNDK、镜像、显示、init、fastbootd 等功能分组，列表采用多行格式，删除过期 recovery-only bring-up 注释。

ADB 开关仍在 Lineage 配置继承前设置；common 的架构/base/device/Lineage 继承顺序保持，ROM 的 common/GSI/vendor 继承顺序保持。所有赋值及产品行为不变。

验证：ROM/recovery 两目标整理前后的产品标识、属性、包列表、文件复制列表、镜像开关、动态分区及 ADB 等求值逐字一致，git diff --check 通过。无需重新构建或刷机；对比输出保存于工作目录 extracted/metadata，不提交 Git。
