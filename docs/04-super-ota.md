# ROM、super 与 zip 后续方案

按用户要求，recovery 能启动并提供 root ADB 后才进入此阶段。当前没有生成或验证可刷 ROM zip。

## 优先路线

保留原厂 4.19.191 kernel 与 vendor（包括内嵌 odm、驱动模块），先验证 LineageOS 19.1 system 与 VNDK31/HAL 的兼容性，再整理 proprietary blobs、系统依赖和 VINTF。
prebuilt kernel 没有问题，但 kernel ABI、原厂模块、DTB/DTBO 必须配套。先不引入小米/三星的内核或模块。

需要处理的真实障碍：原厂 boot first-stage fstab、system_ext 路径、AVB boot/vbmeta_system/vbmeta_vendor 链、MTK policy、vendor 中对系统库的依赖、屏幕/音频/无线/传感器等实际 HAL 验证。当前仅 BoardConfig 的 super 参数不代表 ROM 已可构建或启动。

## 非 A/B 动态分区 zip

- 使用 19.1 的 block OTA / updater，目标是 recovery sideload 安装，非 payload A/B OTA。
- target-files 必须包含正确的 dynamic_partitions_info 和 main group 配置；updater 通过 update_dynamic_partitions 更新 LP metadata，再写 logical block images。
- super 物理大小=7134339072，main group 原厂上限=7132241920；所有最终 logical 分区大小（含 AVB 等）之和必须小于等于上限。
- 初期保持 system/vendor/product 布局，是否新增独立 system_ext 要等 first-stage fstab 和挂载验证后决定。
- 若 zip 不更新 vendor，dynamic partition 操作仍必须保留 vendor 在 main 中，验证 releasetools 的 partition list 和 resize 操作，不能把 vendor 从 group 删除。
- recovery 中 ADB 写物理 boot/recovery 与写 logical system 是不同流程；推荐 logical 分区走 fastbootd。不能直接 `dd system.img` 到不存在的 GPT system，更不能盲写到 super。
- 完整 super.img 可作为另一种工厂刷机产物，用 lpmake/build_super_image 根据确切 group 和分区生成；不把原厂 6.7GiB super 备份简单塞进通用 OTA。

最终验收：target-files 元数据正确、zip 脚本 LP 操作可审查、产物大小正确、干净安装及回原厂流程在实机验证。继续阶段前保留原厂全分区备份和 SHA256。

实现依据：本地 `build/make/tools/releasetools/{ota_from_target_files.py,non_ab_ota.py,common.py,build_super_image.py}`、`system/core/fs_mgr/liblp` 与 `bootable/recovery/updater`；优先按已同步的 19.1 代码实现。
