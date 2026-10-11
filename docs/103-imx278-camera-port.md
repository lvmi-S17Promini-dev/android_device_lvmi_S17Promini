# OSS 相机：IMX278 首次源码移植

2026-10-11。用户要求先从 GitHub 查找 IMX 驱动并移植；随后明确要求代理完成首次成功编译。内核基于已验收启动、cpufreq、Wi-Fi 和 HWC 的现有工作树。

## 源码与原厂核对

找到并下载到 `ref/imx278-candidates/`：

- [Cubot MAX MT6753 IMX278](https://github.com/h0sch180/android_kernel_cubot_max/tree/7450eaa6b7662499002982526e81973ca0e5f433/drivers/misc/mediatek/imgsensor/src/mt6753/imx278_mipi_raw)，提交 `7450eaa6b7662499002982526e81973ca0e5f433`，作为移植基础。同仓库 MT6735 版本也已下载对比。
- [Meizu MT6755 IMX278](https://github.com/ReMeizu/android_kernel_meizu_mt675x/tree/b86c36b01ef08399f064cd2f60cb8fcf6d0b164c/drivers/misc/mediatek/imgsensor/src/mt6755/imx278_mipi_raw)，提交 `b86c36b01ef08399f064cd2f60cb8fcf6d0b164c`，含 Meizu 板级改动，仅作对照。

用 `/home/dengxh/ghidra_12.1.4_PUBLIC/support/analyzeHeadless` 对原厂 raw Image 做定点反编译，基址 `0xffffff8008080000`，不运行全内核分析。脚本 `tools/S17CameraDecompile.java`，输出 `extracted/metadata/ghidra-camera/`。`tools/reverse_imx278.py` 检查原厂 gzip 内核 SHA256 后解析绝对 kallsyms，并生成函数边界和审核报告 `extracted/metadata/stock-imx278-audit.json`。

S17 与候选不同：探测地址列表为 `0x34,0x20,0x40,0xff`；RAW_B，初始化写入 H/V 翻转；预览、拍照和普通录像都输出 2100×1558，480 MHz pixel clock、line 4976、frame 3200。未移植候选 4208×3120 拍照设置。保留原厂 cap1 的 388 MHz/frame 3220 软件声明与相同硬件寄存器表，不自行纠正原厂这处差异。

已逐项核对并对齐 249 项初始化写入、每组 72 项模式写入、5 组裁剪信息、104 项增益映射。其中候选增益表 `{198,247}` 改为原厂 `{198,347}`。

## 接线与修复

内核新增 `drivers/misc/mediatek/imgsensor/src/common/v1/imx278_mipi_raw/`。修改 sensor list 声明/注册、MT6765 上电表，以及 S17 测试 fragment，恢复两个原厂传感器的编译列表。release 标识为 `-s17-bringup-r12-camera`。

原厂主/副摄上电顺序相同，已对齐各电压及延迟；S17 配对配置的副摄 AVDD 由 GPIO 改为 regulator。已有 GC5025sub 寄存器/OTP 实现未重写。

适配当前 struct/enum 类型和内核日志接口；修正 C90 声明顺序、删除未使用的镜像辅助函数及关闭代码；保护零帧率除法；补上 crop 查询的 break，避免落入读取第三参数槽的 HDR 分支。原厂未实现的候选 AWB/ISO 扩展不接入。

内核详细记录：`Documentation/S17Promini-imx278.md`。

## 验证

静态审核脚本通过。新增 C 驱动 checkpatch 为 0 errors / 0 warnings；内核 diff --check 通过。

相机子系统在隔离 `/tmp/s17-camera-build` 编译通过。首次适配出现的 C90 声明顺序和 unused-function 编译错误已修正。最终 `m -j8 bootimage` 结果与镜像检查见本文件后续构建记录。

实机相机仍为 WIP：需要核对主/副摄打开、预览、拍照、录像、切换及关闭再打开，AF/ISP/HAL 和副摄 OTP 未验收。未刷写设备。

## 首次完整构建成功

在 `/home/dengxh/android3/lineage` 执行 `lunch lineage_S17Promini-userdebug`、`m -j8 bootimage`，最终构建成功。产物仍在 `out/target/product/S17Promini/boot.img`，另复制到工作目录 `artifacts/source-camera-r1/boot.img`。旧 boot 在 `artifacts/source-camera-r1/before-camera-boot.img`，用于本轮回退。

- 版本：`4.19.127-s17-bringup-r12-camera+`。
- 新 boot SHA256：`62bb881051172c58aa08c94038a1b10a9b9694e6b52e8faaa2070b12b1b01c65`。
- boot 大小 33554432 字节；源码 kernel/DTB、stock ramdisk、AVB hash 验证通过；cpufreq 初始化保持开启。
- `System.map` 确认 IMX278 init 已链接。对编译 Image 的审核副本应用 ELF 相对重定位后，确认 sensor list 为原厂顺序 GC5025sub index 0、IMX278 index 1，init 指针正确；两传感器上电表与 stock 完全一致，副摄 AVDD 为 regulator。

镜像验证结果：`extracted/metadata/imx278-boot-validation.json`；编译相机表核对：`imx278-linked-camera-audit.json`；完整构建日志：`imx278-boot-build.log`。构建输出有既有配置探测 PATH/oldconfig 及 depmod 提示，最终退出成功；没有为此次相机移植修改构建系统或关闭编译错误检查。

后续由用户安装测试。仅编译和离线验证通过，不将相机标为实机修复成功。

2026-10-11 后续验收：用户确认 r13 相机修复成功，并纠正此前实际默认使用副摄。IMX278 与 GC5025sub 整体修复验收见 [104 号记录](104-camera-front-gc5025sub-stock.md)。
