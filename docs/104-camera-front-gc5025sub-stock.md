# camera-debug：实际前摄取流失败与 GC5025sub 修正

2026-10-11。用户提供 `oss-kernel-debug/camera-debug/`，反馈相机不闪退但“无法连接”，默认以为是主摄。六份原始文件为 UTF-16；保留原件，在 `normalized/` 生成 UTF-8 文本供检索。

## 日志定位

- 内核为 `4.19.127-s17-bringup-r12-camera+ #28`，确认运行新驱动。
- 主摄识别到 IMX278：`0x34`、ID `0x278`；副摄识别到 GC5025sub：`0x6e`、逻辑 ID `0x5026`。不存在把两者未探测成功当作根因的依据。
- `media-camera.txt` 中 camera 0 标为 BACK、camera 1 标为 FRONT。应用在 10:17:04 短暂连接 0，随后进入的三次取流会话都是 camera 1；内核实际执行 `gc5025sub...[control] scenario_id = 1`，没有主摄 control/preview 取流记录。
- 首次 10:17:07.432 的 `TG_CHECK` 报 `seninf vertical data is small than grab window_v:138_1944`，后续有 86/223 对 1944、高度不足或无输入。10:17:15.342 HAL provider 死亡，应用收到 DEAD_OBJECT/Broken pipe，弹出相机错误。10:19 的复现也是副摄取流失败。应用本身未见 Java 崩溃，底层 provider 退出是另一回事。

关键证据在 normalized/dmesg-after.txt 的 10046..10326 附近及 normalized/logcat.txt 的 10546、12374 附近；metadata 的 BACK/FRONT 分别在 media-camera.txt 第 115/995 行。

SELinux 相关拒绝为 permissive=1，本轮未据此改策略；AFVDD NULL 提示保留，不能从该提示推断传感器探测失败。

## 源码修正

已有 common/v1 GC5025sub 是 marlon 重建实现，后续模式设置/streaming 使用另一套寄存器，包括 0x3e；S17 原厂在初始化后保持固定全尺寸输出，模式切换不重写寄存器。这是直接确认的板级差异，可以解释为何 ID 正常而取流异常；最终原因仍需新镜像实测确认。

GitHub 找到 [ZTE GC5025 旧接口驱动](https://github.com/deadman96385/android_kernel_zte_mt6761/tree/b0c0f1ec4cb6d616090e7879a7df0785a1323c5d/drivers/misc/mediatek/imgsensor/src/common/v1/gc5025_mipi_raw)，固定提交 `b0c0f1ec4cb6d616090e7879a7df0785a1323c5d`，下载到 `ref/gc5025-stock-candidate/`。以其 OTP/control 源码为基础，使用用户指定的 Ghidra 对照 S17 原厂 open/get_info/get_resolution/control/feature_control 及 OTP 辅助函数。

新增工程级 `camera_project/r65v3_pmz_w1a/gc5025sub_mipi_raw/` 和工程 Makefile，通过既有优先规则接入。common/v1 原驱动保留。

对齐原厂 107 项初始化写入、五组 2592×1944 裁剪、72 MHz pixel clock、line 2400、frame 988、RAW_R、双 lane、24 MHz MCLK、3 个 SensorModeNum。模式切换不再改写传感器。曝光乘二并限制到 0x3ffe；增益改为原厂 64/92 两档；去除候选独有的 reset-version 探测、数字增益补偿和像素率扩展。

OTP 保留缺陷像素读取/扩展、H/V 变换、排序和 SRAM 写入，以及 chip register patches。DPC checksum 地址改为原厂 0x75；不增加原厂未应用的 AWB 校正。修正候选空列表排序下溢和末项越界读，对超过 50 的输入记录数拒绝解析。具体边界见内核 `Documentation/S17Promini-gc5025sub.md`。

版本标识更新为 `-s17-bringup-r13-camera`。主摄实现未修改。

## 验证与后续

`tools/check_s17_gc5025sub.py` 通过：107 项 init、5 组 crop、5 组 timing 对照；直接抽取实际驱动函数做 ASan/UBSan 主机测试，覆盖 OTP 空/0/4/200 缺陷、非法记录数、SRAM 顺序、chip patch、曝光/增益和模式不写寄存器。驱动 checkpatch 0 errors / 0 warnings。

本轮不操作手机。新镜像需要分别复测真正的 BACK（camera 0）和 FRONT（camera 1）的预览、拍照、录像与切换。主摄当前只能确认识别/初始化通过，不能标为取流成功。完整构建及镜像记录另附本文件末尾。

## r13 构建与交付

最终 `lunch lineage_S17Promini-userdebug`、`m -j8 bootimage` 成功；版本 `4.19.127-s17-bringup-r13-camera+`。

新 boot：`artifacts/source-camera-r2/boot.img`，SHA256 `dbde29902a14046d73f02d60816b1e993da814c5569fe6226481baff4f6dc7a6`。标准输出同为 `~/android3/lineage/out/target/product/S17Promini/boot.img`。r12 的 `artifacts/source-camera-r1/boot.img` 保留。

源码 kernel/DTB、原厂 first-stage ramdisk、32 MiB 大小及 AVB hash 验证通过；cpufreq 初始化仍开启。构建对象路径及其编译命令确认使用工程级副摄实现。

记录：`extracted/metadata/camera-r13-build.log`、`camera-r13-validation.json`、`camera-debug-analysis.json`、`stock-gc5025sub-audit.json`、`gc5025sub-host-tests.log`。主摄审核脚本仍通过。未刷写、未提交，副摄实机取流是否恢复待用户复测。

## 实机验收

2026-10-11，用户反馈“修复了”，并明确纠正此前默认已切到副摄，与日志的 camera 1／FRONT 对应。r13 相机修复标记实机通过。

此次反馈为整体相机修复确认，未提供新日志或逐项测试清单；不将录像、AF、各模式和前后摄切换分别记录为单项已验收。先前主摄无法连接的判断已由日志和用户更正，不保留为当前故障结论。

用户要求提交后，内核修复提交为 `baf7087dab3c`（S17Promini: Restore stock IMX278 and GC5025sub camera support）。
