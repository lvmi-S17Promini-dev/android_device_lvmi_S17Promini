# 清理版 prebuilt vendor 构建（2026-10-06）

第一版在原始 LP vendor.img 上重打包，而非用 rdump 工作目录直接生成全新文件系统：rdump 日志存在无法恢复 owner 的记录，原镜像可保留原厂 UID/GID、mode、SELinux/capability xattr、symlink、HAL、属性、fstab、VINTF 和 MTK CIL。当前仍为 prebuilt vendor bring-up，尚未生成逐库源码/Soong 模块的完整 vendor 移植，也没有 OTA zip。

DT proprietary-files.txt 保留 1875 个普通文件；proprietary-files-removed.txt 记录从原始 2050 文件基线移除的 175 个文件。工具先检查原镜像普通文件与两个清单完全匹配，再复制镜像、移除旧 AVB footer、用 debugfs 删除列出的文件及空应用目录，验证 ext4 并缩小文件系统，重新生成 NONE AVB hashtree/FEC 和 sparse 镜像。188 个原有符号链接保留。

extract-files.sh 在此阶段输入原始 raw LP vendor.img，不是 adb 或解包目录；调用重打包工具。setup-makefiles.sh 生成 vendor/lvmi/S17Promini 的 BoardConfigVendor.mk 与 S17Promini-vendor.mk，system 产品通过 BOARD_PREBUILT_VENDORIMAGE 接入。PRODUCT_BUILD_VENDOR_IMAGE=false 关闭从散文件生成 vendor 的流程；m vendorimage 仍会将准备好的 prebuilt 复制至产品输出目录。该配置仅用于 lineage_S17Promini_system，r5 recovery 产品不变。

## 构建

```sh
cd ~/android3/lineage
./device/lvmi/S17Promini/extract-files.sh ~/S17Promini_LineageOS/extracted/super/vendor.img
source build/envsetup.sh
lunch lineage_S17Promini_system-userdebug
m -j4 vendorimage
```

清理规则变化后先重新运行 extract-files.sh；单独 m vendorimage 不会重新处理删除清单。所有修改都在镜像副本，原始 LP vendor.img 和 stock_imgs 不改；无需 sudo。

输出：out/target/product/S17Promini/vendor.img。第一版验证报告：

- sparse 文件：1221694332 bytes
- 展开分区：1427996672 bytes，保持原 logical vendor 大小
- ext4 文件系统：1208631296 bytes
- SHA256：7f96a5ca8ac16957df39933a1b6c62bf329720f12263f32929bd3063cf2f9fe3
- e2fsck、AVB hashtree 校验通过；全部保留路径的 mode/UID/GID/size 与原镜像一致，代表文件 xattr 一致。

## 实机测试

当前保留已验证 system/boot 和 flags=3 的禁用验证 vbmeta，仅更新 vendor。先在 r5 recovery 进入 fastbootd：

```powershell
adb reboot fastboot
fastboot getvar is-userspace
# 确认 yes 后：
fastboot flash vendor .\vendor.img
fastboot reboot
```

刷后复测相机、扬声器、麦克风、Wi-Fi、蓝牙、充电、唤醒；确认 6 个独立预装应用不再由 vendor 安装。已有应用若存在 /data/app 更新副本，删除 vendor 文件不会自动删除该副本。该镜像现已通过实机验证，结果见下文。

早期免授权 ADB 是上一轮 system 改动，单独刷 vendor 不会启用；需另行 m -j8 systemimage 并刷新的 system.img。当前先只更换 vendor，方便定位问题。

Lineage 构建验证：`m -j4 vendorimage` 成功，输出已复制到 `~/S17Promini_LineageOS/artifacts/vendor-firstboot/vendor.img`，SHA256 与工具报告一致。

实机验证：用户刷入清理版 vendor 后清空 data，成功开机，确认没有原厂预装应用，功能测试正常。未逐项新增测试明细，按用户反馈记录。对应构建 DT 提交 082c729，镜像 SHA256 见上；保存为后续展开 blob、重建 vendor 的对照基线。
