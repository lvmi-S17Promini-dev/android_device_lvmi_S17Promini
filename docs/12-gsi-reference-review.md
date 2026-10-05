# GSI Clean ROM Kit 参考复核

用户链接：https://github.com/mr-tbot/S17-Max-Mini-A25-MediaTek-MT6765-MT8768t-Helio-P35-G35-Clean-ROM-Kit/blob/main/INSTRUCTIONS.md
快照 commit `95c49af5d2f1362b4b7b9e6d0db05f90369822a2`，相关文档与树清单存 `ref/gsi-clean-rom-kit`。只下载了文本，未下载、运行刷机脚本或镜像。

## 有参考价值

- 作者自述 Welcome/iku A25、MT6765/MT8768t、Android 12 arm64 Google GSI 成功启动，保留原厂 boot/kernel/vendor。
- super=7134339072、boot/recovery 32MiB、metadata-size=65536、metadata-slots=2，与本机一致。
- 将公开 CHECKSUMS.sha256 与本机已有备份 SHA256 比较：gpt.bin MATCH，vbmeta.bin MATCH；boot/recovery/lk/lk2/seccfg DIFFERENT。这里只比较作者发布的校验和值，没有下载其备份镜像验证。说明分区布局高度相关，不能把全部二进制视为本机可替换。
- BROM 关机双音量插 USB 方式与本机一致。
- 报告 PowerVR GE8320 在 GSI SkiaGL 路径崩溃，使用 debug.renderengine.backend=gles。19.1 本地 RenderEngine.cpp 确实识别 gles；本机 stock vendor/build.prop 设置 skiagl。它是后续 SurfaceFlinger 崩溃的候选兼容性设置，**不是已验证本机必需的修复，也不用于 recovery/fastbootd**。
- 它的成功记录保持 SELinux Enforcing，不能用作必须关闭 SELinux 的证据。

## 不能照抄的部分

1. INSTRUCTIONS 的 lpmake 示例只声明 system，输出一个新完整 super；如果直接按示例重建并刷写，会缺少 vendor/product。README/HOW-I-DID-IT 又说保留原厂 vendor，步骤不自洽。我们的实际 super 要保留或明确生成 system/vendor/product 和 main group，按 liblp 验证。
2. “取原 LP metadata”的命令实际 dd /dev/zero，不是读取原始 metadata；手工按 1MiB offset 拼接/truncate 不代表 metadata 表/checksum正确。
3. 文档对 vbmeta flags 解释不准确：AVB 实际 HASHTREE_DISABLED=1、VERIFICATION_DISABLED=2，组合为3。AVB 与 SELinux 不同，不通过刷 vbmeta 来关闭 Enforcing。
4. 作者配置 wm size 720x1520（README又为720x1600），本机物理屏幕384x854，不能照搬显示覆盖或dpi。
5. repo 报告的机型、brand和 vendor 日期与本机不同，且 boot/LK/recovery 校验和不同；不使用他人的 boot/LK/calibration 唯一分区备份作为恢复源。
6. 作者声称的 malware/security 审计缺少本机证据，不纳入我们对本机系统的事实判断；不能凭这些文本保证 ROM 的安全属性。

## 对移植路线的影响

加强了“保留本机预编译 kernel/vendor，以 Android 12/12L 系统先启动验证”的依据；后续仍以 LineageOS 19.1 为目标，不自行改目标去刷他人的 Google GSI 镜像。
fastbootd r3 若可识别 logical partitions，先用现有布局验证替换 system 的路径；若需完整 super 工厂镜像，用 lpmake/build_super_image 正确保留 vendor/odm、明确处理 product/system_ext，而非复用文档的单 system 命令。
目前未修改 ROM 属性、AVB 或分区内容，没有进行 GSI 刷写。
