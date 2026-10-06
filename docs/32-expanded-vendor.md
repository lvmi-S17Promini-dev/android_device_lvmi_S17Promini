# 展开 vendor blob 与按文件构建（2026-10-06）

上一版 vendor-clean-r1 已由用户确认开机、清 data 后无原厂预装 app、功能正常。本轮将 vendor/lvmi/S17Promini/proprietary 改为展开的 vendor/... 文件树，1875 个普通文件、188 个真实符号链接；旧整镜像副本从 proprietary 移除，验证过的镜像保留在工作目录 artifacts/vendor-firstboot。

## 构建输入

extract-files.sh 从原始 raw LP vendor.img 按 proprietary-files.txt 提取文件，并从 inode 导出 UID/GID、mode、SELinux 标签、链接目标；按 proprietary-files-removed.txt 排除已删除应用和 recovery 恢复组件。原厂没有 security.capability xattr；工具对未支持的 capability 明确报错，不忽略。

DT vendor-config/metadata.json 为元数据来源；setup-makefiles.sh 根据它生成 fs_config/file_contexts，并生成 vendor 项目的 Android.mk、BoardConfigVendor.mk、S17Promini-vendor.mk。修改权限或标签时先修改 metadata.json，再运行 setup-makefiles.sh；文件内容可直接修改展开的 blob。丢失 root、目录或链接元数据会导致新镜像构建验证失败。

m vendorimage 的依赖是全部展开文件及元数据配置。Android.mk 用 AOSP mkuserimg_mke2fs/e2fsdroid 从文件新建 ext4，随后添加 AVB hashtree/FEC，再生成 sparse 镜像；构建过程不读取 stock image。stock image 只用于首次提取。

闭源 MTK CIL、VINTF、fstab 和 vendor 属性仍使用 stock blob。为避免通用 vendor 生成流程覆盖这些内容，BOARD_PREBUILT_VENDORIMAGE 指向由 Android.mk 构建的中间产物，PRODUCT_BUILD_VENDOR_IMAGE=false；这不是 proprietary/vendor.img 整镜像 blob，也尚未转换为逐库 cc_prebuilt_library_shared/Soong 模块或源码 vendor 策略。

## 命令

首次提取（会替换展开文件树；之后不要在修改 blob 后重复执行）：

```sh
cd ~/android3/lineage
./device/lvmi/S17Promini/extract-files.sh ~/S17Promini_LineageOS/extracted/super/vendor.img
```

通常构建：

```sh
source build/envsetup.sh
lunch lineage_S17Promini_system-userdebug
m -j4 vendorimage
```

输出 out/target/product/S17Promini/vendor.img。修改配置后先运行 device/lvmi/S17Promini/setup-makefiles.sh。当前只用于 system 产品，recovery 产品不变；不修改 system/boot/vbmeta 或 userdata。

## 验证与实机

从新镜像重新读取全部 inode，核对 UID/GID/mode、SELinux 标签、链接目标；重新导出全部 1875 个文件，逐个比对输入 SHA256；ext4 和 AVB 校验通过。e2fsdroid 特殊处理 lost+found，不从源目录复制该目录，交给 mke2fs 创建后设置标签；该目录元数据同样经过核对。

新 sparse 镜像约 514 MiB，分区展开大小仍为 1427996672 bytes。未实机验证。用 r5 recovery 进入 fastbootd，仅刷 vendor，保留当前能启动的 system/boot/vbmeta，不需要清 data，再复测硬件功能。刷写方法与上一版相同。

Lineage 构建验证：m -j4 vendorimage 成功。产物已保存到 ~/S17Promini_LineageOS/artifacts/vendor-expanded-r1/vendor.img；sparse 538035712 bytes，SHA256 7f2411ff41dbaf2dfa7b6a8fa56ebc79baee5ce115908e48b2fb7c30021b4af4，复制后 SHA256 一致。本机需要 e2fsprogs 的 /usr/sbin/debugfs（可通过 S17_DEBUGFS 指定其他绝对路径），以便绕过 Android PATH 工具过滤并校验 inode。脚本兼容构建环境的 Python 3.9。
