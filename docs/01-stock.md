# 原机与镜像分析（2026-10-05）

用户提供：lvmi S17Promini / MT6765V Helio P35 / 4GB+64GB / Android 12 API 31 / Linux 4.19.191 / Treble / 非 A/B / 独立 recovery，已通过 mtkclient 解锁并备份除 userdata 之外的分区。
原厂属性品牌写作 `IVMI`，设备树按用户要求使用 `lvmi`。

## 已从备份确认

- boot/recovery：Android boot header v2，pagesize=2048，kernel gzip，64 位；原厂 userspace 支持 arm64 和 arm。
- kernel 地址 `0x40080000`；ramdisk `0x51b00000`；tags/DTB `0x47880000`。
- 原厂 cmdline：`bootopt=64S3,32N2,64N2 buildvariant=user`。
- boot 与 recovery 的 kernel 大小都是 10990316，DTB table 大小 109220；recovery 内嵌 DTBO 45244。
- boot/recovery 分区各 33554432 bytes；vendor_boot 分区 67108864，**整个备份全零**，不能启用 vendor_boot 构建。
- 原厂系统 fingerprint：`IVMI/S17Promini/S17Promini:12/SP1A.210812.016/mp1V15240:user/release-keys`。
- 原厂 system/vendor patch=`2024-03-05`，vendor VNDK=31，shipping API=31，board first API=30，VINTF target-level=5。
- 原厂 density=180；recovery pixel format=`BGRA_8888`；用户实测物理屏幕 384×854；按键、触摸方向待实机确认。
- SELinux `CONFIG_SECURITY_SELINUX_DEVELOP=n`，BOOTPARAM/DISABLE 也未启用；不能指望 cmdline permissive 或 setenforce 排障。
- USB 支持 configfs/functionfs，原厂 recovery 控制器 `musb-hdrc`，`sys.usb.ffs.aio_compat=1`。

## super（原厂 LP metadata）

| 项目 | bytes |
|---|---:|
| super GPT 分区 | 7134339072 |
| main group 最大大小 | 7132241920 |
| system | 3063197696 |
| vendor | 1427996672 |
| product | 204660736 |

LP v10.0，metadata max=65536，metadata slots=2，logical block=4096，alignment=1048576。这里的两个 metadata slots **不表示 A/B 系统**。
实际 logical partitions 只有 system/vendor/product，没有独立 odm/system_ext。
`/odm` 路径转到 `/vendor/odm`；system_ext 文件在 system 镜像的 `/system/system_ext`。
原厂 fstab 中仍有 system_ext logical 项，是模板残留，recovery 不照搬。

## metadata 特例

原厂 fstab 把 `/dev/block/by-name/md_udc` 挂为 `/metadata`，备份证明确为 ext4（23699456 bytes）；GPT 同时存在的 `metadata` 分区全零。recovery 采用 md_udc。FBE 配置为 `aes-256-xts:aes-256-cts:v2`、`keydirectory=/metadata/vold/metadata_encryption`；暂不承诺解密 data。

## 分类与原始证据

- `stock_imgs/`：原始 bin 保持不动。
- `classified/`：按 boot/android/firmware/device-unique/layout-and-state 分类的 `.img` 符号链接，无额外大文件复制。
- `extracted/boot`、`extracted/recovery`：kernel、DTB、ramdisk 和 ramdisk-root；recovery 多一个 recovery_dtbo。
- `extracted/super/`：解出的三个 raw ext4 镜像。
- `extracted/filesystems/{system,vendor,product}/`：用 debugfs 解出的文件。绝对符号链接保留，主机读取时需映射到解包目录；rdump 不保留原机 UID/GID（日志中的 chown 权限错误为预期）与 Android SELinux xattr，不能直接据此重建 stock vendor。
- `extracted/metadata/`：GPT/LP JSON、所有原始备份 SHA256、启动头、AVB 信息、DTS、规范化 kernel.config、构建日志。

工具用 LineageOS 已有 unpack_bootimg.py/lpunpack/avbtool.py 和主机 debugfs/cpio/dtc，全程不需要 root。

```bash
cd ~/S17Promini_LineageOS
./tools/extract_stock.sh ~/android3/lineage
```

设备唯一数据（nvram/nvdata/nvcfg/protect/proinfo/otp 等）作为恢复备份保留，不合入公开 ROM 或通用刷机包。
