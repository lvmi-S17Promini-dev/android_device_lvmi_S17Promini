# 移植过程

## 2026-10-05：recovery 第一阶段

1. 解 boot/recovery、读取 GPT/LP、解 super 与 ext4，建立分类和 SHA256 清单。
2. 规范化 adb 导出的 kernel.config（原文件含字面 `\r\n`，保留原件）。
3. 拉取参考 [kelexine/android_device_cubot_marlon](https://github.com/kelexine/android_device_cubot_marlon)，commit `07c34ee1a5ce62e331414ccd8bbb404c459c0615`。当前 lineage-23.2 分支默认源码内核，预编译为可选；仅参考结构，不照搬新版本 extract-utils、分区尺寸或 HAL 配置。
4. 建立 `device/lvmi/S17Promini`，产品 `lineage_S17Promini-userdebug`，使用原机 recovery kernel/DTB/内嵌 DTBO。
5. 精确配置 boot header v2 / base / 各 offsets；不构建 vendor_boot；不把独立 dtbo 分区误作 recovery 内嵌 DTBO。
6. recovery fstab 只列实际 logical partitions 和所需物理分区；misc 对应 para，metadata 对应 md_udc。
7. recovery 使用 enforcing，init 配原厂 configfs/UDC；debug recovery 关闭 ADB 认证并由 Lineage recovery 启动 root adbd，避免依赖 data 解密拿 adb_keys。
8. 首次 `m -j8 recoveryimage` 成功（6 分 4 秒）；随后编译 host fastboot 成功，按原厂 BGRA_8888 修正像素格式再编译并静态验证。实机启动、USB、显示、按键、fastbootd 都待验证。

## 构建

```bash
cd ~/android3/lineage
source build/envsetup.sh
lunch lineage_S17Promini-userdebug
m -j8 recoveryimage
```

产物路径 `out/target/product/S17Promini/recovery.img`；日志 `~/S17Promini_LineageOS/extracted/metadata/build-recovery-verified.log`。
阶段 1 BoardConfig 的 AVB=false，仅供解锁设备 recovery 测试，未证明 LK 接受未签名镜像。原厂 recovery 有 SHA256_RSA2048 AVB footer；若 LK 拒绝，需要根据具体报错处理，不能盲刷 vbmeta 链。

## 问题与限制

| 问题 | 处理 / 状态 |
|---|---|
| vendor_boot 不是有效镜像 | 全零，阶段 1 不使用 |
| 原厂 fstab 包含不存在的 system_ext LP | recovery 去掉；ROM 阶段需重新处理 boot/vendor first-stage fstab |
| 原厂 md_udc 实际作为 metadata | 依原机配置，不能按名称猜 |
| 内核不支持 permissive 切换 | 去掉 permissive 参数；后续按 AVC 精确补 policy |
| marlon 当前分支不同、默认源码内核 | 不直接复制，按本机和 19.1 配置 |
| ADB 未连接设备 | 实机验收待用户测试；不需要 Magisk |
| data FBE 解密 | 阶段 1 未实现，不做 wipe 测试 |
| full ROM / OTA | 等 recovery 实机通过后继续，当前树不能当完整 ROM 发布 |

原厂 vendor 有 `bin/install-recovery.sh`、`etc/init/vendor_flash_recovery.rc` 和 `recovery-from-boot.p`，刷入自定义 recovery 后启动原厂系统可能恢复 stock recovery。首次优先临时 fastboot boot；持久化阶段再处理该机制。

## 源码版本

- build/make: `ec4184bcd771e59d3d108115507587444697be38`
- bootable/recovery: `7c1eb300fbcf789024da690c96adb167d31aa5a5`
- vendor/lineage: `48deacfcdcdd6338c5b1cf88e53364db92adf854`

主机 fastboot：`~/android3/lineage/out/host/linux-x86/bin/fastboot`，版本 `31.0.2`。

## 第一阶段构建结果

最终 recovery 编译成功（增量 1 分 10 秒），大小 20754432 bytes，小于 recovery GPT 容量 33554432。
镜像副本：`~/S17Promini_LineageOS/artifacts/recovery.img`；SHA256：`020fc3e3c7f82bfe0be10e532b086e1d05c55d87a2e14d2c0470876a55ec1586`。

`tools/verify_recovery.py` 静态检查通过：kernel/DTB/recovery DTBO 与 stock 字节一致；加载地址、页大小、v2 header 正确；debuggable/BGRA/UDC/ADB 配置正确；adbd/recovery/fastbootd/sh 与直接 ELF 依赖存在。
header OS=12.0.0、patch=2025-03（来自已同步源码）；原厂 patch=2024-03。没有修改厂商签名链，没有刷写设备。
**编译及静态通过不等于实机可启动**。fastboot boot、显示、root ADB、SELinux AVC 和 fastbootd 未实测。

复验命令：

```bash
cd ~/S17Promini_LineageOS
python3 tools/verify_recovery.py ~/android3/lineage
```

## 实机更新

用户实测原厂与自编 recovery 都 fastboot boot 失败，设备显示 usb transfering 后重启回原厂系统。暂时弃用临时启动路线，下一步先验证 fastboot reboot recovery，再安排独立 recovery 分区测试；见 06-device-test.md。

## 窄屏资源调整

原机 384×854，原先使用默认 mdpi 文本；本次改成显式按本机宽度生成的私有文本，此调整不作为 fastboot boot 失败的解释。尝试设置 UI_SCREEN_WIDTH=384 后，LineageOS 19.1 ImageGenerator 的固定 40px 字号使窄屏部分长词触发空行，报 `IllegalArgumentException: Can't add attribute to 0-length text`。失败日志 `extracted/metadata/build-recovery-384.log`。

最终取消 UI_SCREEN_WIDTH 自动生成，使用 device/recovery/res/images 内预生成的 18px 多语言文本，图片宽度最大 373px。调用同一个 ImageGenerator 的公开 API，未修改公共 recovery 源码。设备树 tools/GenerateRecoveryText.java 和 generate-recovery-text.py 可再生成资源：

```bash
cd ~/android3/lineage
source build/envsetup.sh
lunch lineage_S17Promini-userdebug
m RecoveryImageGenerator
python3 device/lvmi/S17Promini/tools/generate-recovery-text.py
m -j8 recoveryimage
```

已预生成并纳入设备树，正常构建不需要先执行再生成步骤。最终日志 `extracted/metadata/build-recovery-384-final.log`。

新镜像：`artifacts/recovery-384.img`，大小 20840448 bytes，SHA256 `8845c801b93b0f5f795d37f761f95f2a5c0b5a702957a209612576c7ec773004`。最终编译成功（1 分 3 秒），解包检查通过，私有文本与设备树逐字节匹配且宽度不超过 374px。旧 recovery.img 未覆盖。实机刷入与启动待验证。

## recovery 启动验收更新

用户已反馈自编 recovery 启动并显示正常。下一步验收 root ADB、USB 状态、分区访问与 fastbootd；在这些结果明确前不将完整 ROM/OTA 标记可用。

## 日志验收与 r2 修复

root ADB、Enforcing、USB adb、cache 挂载和物理分区节点已通过日志确认；触摸用户确认不可用，AXS 固件更新读回校验失败，待 getevent 分层排查。补齐五张缺失的 wipe/重试确认文字 PNG，保留完整语言集。data 挂载失败暂按未解锁元数据加密排查，不做格式化。详见 08-recovery-log-review.md。

触摸 getevent 复核：axs_ts/event3 与 mtk-tpd/event4 均注册，触摸采集无实时事件。优先检查驱动/固件/IRQ 状态，暂不改 UI 坐标。fastbootd 输出仍待补，详见 09-touch-input-review.md。

## fastbootd 更新

用户实测 is-userspace=yes，但 is-logical:system/partition-size:system 失败。按本地 fastbootd 和 SELinux 规则分析，缺失 super 专用标签为首要假设，r3 补 file_contexts，保持 enforcing；未操作 super。详见 10-fastbootd-super.md。

## SELinux 与 GSI 参考补充

上游 4.19 域 permissive 与全局 DEVELOP 开关分离；当前 recovery/su/backuptool 已为 permissive domains，全局仍 Enforcing。fastbootd 可考虑单域 permissive 对照试验，但 r3 未改变此域。用户提供 GSI kit 文档已复核，公开 GPT/vbmeta 校验和值与本机相同，boot/LK/recovery 不同；提取保留 vendor 与 GLES 后端线索，不照搬仅声明 system 的 super 重建命令。详见 11/12 文档。

## r3 实机回归

用户报告 r3 启动失败。离线完整对比 r2/r3 只有 vendor_file_contexts 两条规则变化；kernel/init/sepolicy 均相同。暂不生成新试刷镜像，先回退 recovery-384 并采集完整刷写输出与 pstore。详见 13-r3-boot-regression.md。

## super 标签实机确认

用户在已验收 recovery-384 中将真实 super 节点从 block_device 改为 super_block_device，再从菜单进入 fastbootd：is-logical:system=yes，size=0xB694B000，等于 stock LP 大小。原因确认。pstore 仅保留原厂运行记录，r3 启动失败尚未定位。r4 从384基线仅加自动chcon，额外确认图片移出默认资源；详见15文档。

r4 构建成功，和已验收384逐文件对比仅 init RC 改变（自动执行实测成功的 chcon），init verifier 通过；五张确认资源暂不打包，vendor contexts/compiled sepolicy恢复基线。实机启动待验证。
