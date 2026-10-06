# 移除 recovery 恢复组件（2026-10-06）

用户实测原厂系统下刷入 Lineage recovery 后并未被恢复；保留该观察，不将文件存在等同于成功执行。

原厂 vendor 存在 class main/oneshot 的 vendor_flash_recovery 服务，执行 install-recovery.sh，使用 applypatch 和 recovery-from-boot.p 从 boot 重建 recovery。是否能成功还取决于服务执行、权限及原厂 boot 的源 SHA1；本轮不再追查历史未触发原因。

按用户要求从解包 vendor 工作目录及 DT blob 清单删除：

- vendor/etc/init/vendor_flash_recovery.rc
- vendor/bin/install-recovery.sh
- vendor/recovery-from-boot.p

applypatch 通用程序及原厂备份保留。其他 vendor init 文件未发现对上述服务/脚本的引用。清单现有 1875 个普通文件；手机端要等新 vendor 镜像刷入才生效。本轮未构建/刷写。
