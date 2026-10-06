# 首版非 A/B 全量安装 zip（2026-10-06）

新增构建目标 m s17-installzip，沿用 lineage_S17Promini_system-userdebug。DT Android.mk 依赖 system/vendor/boot/vbmeta 镜像、静态 updater 和已实测 r5 recovery，调用 AOSP 19.1 BlockImageDiff 为 system/vendor 生成 v4 transfer.list/new.dat/patch.dat；使用 signapk 全文件签名。工具需要树内 Python 3.9，避免宿主 Python 3.13 的 imp 移除问题。

## 构建

```sh
cd ~/android3/lineage
source build/envsetup.sh
lunch lineage_S17Promini_system-userdebug
m -j8 s17-installzip
```

这是首版全量安装包，尚未接入标准 target-files/m bacon、增量 OTA 或自动更新。vendor 仍由之前的逐文件规则生成，recovery 使用 prebuilt/r5 保持实测配置；不会因 ROM 产品重新编译 recovery 而改变其策略。

## 安装内容

更新 system、vendor、正常 boot、flags=3 vbmeta、r5 recovery。要求本机已存在原厂 LP 名称 system/vendor/product 和 main group；不 remove_all_groups，不刷整块 super，不改 product、userdata、LK、dtbo 或其他固件，不自动 format data/cache。

LP 操作先将 system/vendor resize 到 0，再设置 main group 上限 7132241920，分配 system=2107789312、vendor=1427996672。原厂 product=204660736 保留，三者合计在 group 预算内。脚本写逻辑分区时用 map_partition，写完用 range_sha1 校验目标数据，再写物理 recovery/boot/vbmeta。

unmount 覆盖 /system_root、/system、/vendor，以免 SAR 挂载占用旧 dm。updater 沿用 recovery 的执行环境；r5 已实测的 super relabel 服务提供正确块设备标签。userdebug recovery 仍为当前调试配置。

## 验证

m s17-installzip 构建通过；transfer.list 仅有 new/zero/erase，无增量源依赖和 stash；new.dat 长度与全部 new block 数一致。包内 boot 和 recovery 字节与相应产物一致，脚本未包含 format/remove_all_groups，分区预算和签名/footer 已检查。r5 的 otacerts.zip 含 testkey.x509.pem，与本包签名证书一致；整体 CMS 签名的主机校验通过，签名证书与 testkey 一致，结果记录在工作目录 extracted/metadata。实机 sideload/启动仍待验证。

产物：~/S17Promini_LineageOS/artifacts/rom-install-r1/lineage-19.1-S17Promini.zip
大小：1142214334 bytes
SHA256：63f631c04cf003198b27efc9dcad174d6fe36a795b290822c70055efa343696e

## 测试

先验证正常 boot，再进入 r5 recovery，按键选择 Apply update → Apply from ADB：

```powershell
adb reboot recovery
adb sideload .\lineage-19.1-S17Promini.zip
```

安装成功后回主菜单选择 Reboot system now。当前已有 Lineage 数据可以保留；首次从原厂系统安装时仍按此前步骤在 recovery 清 data（不由 zip 自动执行）。不要在 fastbootd 模式执行 sideload。

若安装失败，回 recovery 菜单恢复普通 ADB 后取 /tmp/recovery.log 和 /cache/recovery/last_log；若文件不见，先确认 cache 已挂载并使用绝对路径。用户无需重复上传完整分区备份。
