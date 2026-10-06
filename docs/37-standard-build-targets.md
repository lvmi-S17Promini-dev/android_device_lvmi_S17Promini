# 正式 ROM / recovery 目标与标准 OTA（2026-10-06）

用户已确认保留 data 升级和清 data 全新安装均正常；本轮不重复这些实机测试，仅整理构建目标和验证软件产物。

## 目标

- ROM：lineage_S17Promini-userdebug，生成正常 boot、system、逐文件构建 vendor、r5 prebuilt recovery、vbmeta 和标准 target-files/OTA。
- 独立 recovery：lineage_S17Promini_recovery-userdebug，仅生成 recovery；配置解析确认 BUILDING_SYSTEM_IMAGE 为空、BUILDING_RECOVERY_IMAGE=true、BOARD_AVB_ENABLE=false，沿用原恢复环境源码配置。
- 原 lineage_S17Promini_system 试启动目标移除；公共品牌/架构相关继承整理到 common.mk。

## 标准构建

```sh
cd ~/android3/lineage
./device/lvmi/S17Promini/setup-makefiles.sh
source build/envsetup.sh
lunch lineage_S17Promini-userdebug
m -j8 bacon
```

独立 recovery：

```sh
lunch lineage_S17Promini_recovery-userdebug
m -j8 recoveryimage
```

源码首次准备仍用 extract-files.sh 提取 vendor blob；setup-makefiles.sh 生成 vendor 构建文件并自动检查/应用 DT patches/build-make-prebuilt-target-files.patch。旧自定义 make-install-zip.py 留作历史参考，新正式目标不再调用它；增量 OTA 本轮不处理。

## 构建支持与布局

19.1 build/make 对上述 prebuilt 组合缺少 target-files 支持，DT 保存一个小补丁：支持直接复制 prebuilt recovery、按 AVB 要求封装，打包 recovery 到 IMAGES；复制展开 vendor 目录、stock filesystem config 和 vendor.map 到 target-files，以便标准 releasetools 读取属性及 block map。补丁没有修改运行时系统组件；setup 重复运行不会重复应用。

vendor-blobs.py 现在同时通过 mkuserimg_mke2fs -B 导出 vendor.map，Android.mk 将 map 声明为隐式输出。缓存分区实际大小 452984832，标准非 A/B OTA 必须有 cache_size 元数据，因此开启 cache image 生成；OTA 不据此自动清 data 或刷 cache。

ROM 保留已验证 stock boot ramdisk，target-files 显式携带生成的 boot.img；recovery 内容保持 r5，增加 footer/padding 满足标准 AVB 镜像大小检查。标准 OTA 的 vbmeta 写入由设备 releasetools.py 的 FullOTA_InstallEnd 补充，使用 flags=3 的构建产物；recovery.fstab 增加 vbmeta 条目用于标准脚本生成。

product/system_ext 仍融合在 system，GSI skip_mount 配置沿用。原先独立 product 未被系统挂载；正式 LP 分区列表调整为 system/vendor。标准全量 OTA 根据 main group 重建 LP 布局，移除不用的原厂独立 product，而 userdata、LK、dtbo 和其他物理固件分区不改。recovery 的 /metadata 仍对应 md_udc、misc 仍为 para。

验证重点是目标解析、target-files 的镜像/属性/fstab/cache/map/dynamic metadata、标准脚本的 LP 操作与物理分区写入、签名，以及 boot/recovery 启动内容保持一致。已验证 r3 安装包继续保留作为实机基线。

标准 OTA 的 VINTF 校验需要设备专用声明；从原厂 framework device matrix 导入 56 个 optional HAL 条目到 compatibility_matrix.xml，DEVICE_FRAMEWORK_COMPATIBILITY_MATRIX_FILE 接入后完整 VINTF 检查通过，未关闭校验。

标准 non-A/B OTA 原本依赖启动时自动恢复 recovery，而本机 vendor 已删除该组件，因此 FullOTA_InstallEnd 直接写 recovery.img 和 vbmeta.img。ROM recovery 的 kernel/ramdisk/DTB 启动内容保持 r5，仅补齐 32MiB 和 AVB footer；不重复安装路径实测。

最终验证：m -j8 bacon 成功，正式 OTA 为 lineage-19.1-20261006-UNOFFICIAL-S17Promini.zip，大小 1009914093 bytes，SHA256 4fbb93a89506167eb0d58e832926007b8c68e47f2be2d5898c99ac8ee553f220。target-files 位于 /home/dengxh/android3/lineage/out/target/product/S17Promini/obj/PACKAGING/target_files_intermediates/lineage_S17Promini-target_files-eng.dengxh.zip。整包签名使用官方 check_ota_package_signature 工具校验通过；meta、vendor.map、VINTF、boot 启动内容及 r5 recovery payload 对照通过；安装脚本更新 system/vendor/boot/recovery/vbmeta，没有 format data/cache。框架补丁提交 0aea4fc49，DT 保存完整 patch。新标准 OTA 不重复实机安装路径测试，原 r3 实机基线保留。
