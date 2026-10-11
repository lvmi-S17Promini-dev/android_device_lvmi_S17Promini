# S17Promini 设备树成熟化 Roadmap

更新：2026-10-06。范围固定为 LineageOS 19.1，不升级 Android；此文件记录后续计划，不代表立即开始修改。

## 已验证基线

- [x] 原厂 prebuilt kernel/DTB、stock first-stage ramdisk 的正常 boot。
- [x] 当前源码生成 recovery，显示、ADB、按键操作及 fastbootd 可用；super 标签修复已验证。
- [x] vendor blob 展开、移除不需要的预装应用，按文件重建 vendor；保留必要的原厂 HAL/固件/策略。
- [x] 正式 ROM/recovery lunch 目标分开；标准 target-files、m bacon、非 A/B 全量 OTA、VINTF 和签名检查通过。
- [x] 用户确认正式安装包刷入、开机及基本功能正常。
- [x] 用户确认保留 data 升级、清 data 全新安装均正常，后续不作为未完成项重复验证。
- [x] RIL、Wi-Fi、相机、声音、蓝牙、麦克风、充电、按键唤醒、Doze 已反馈正常；具体测试范围以已有记录为准。
- [x] 调试 ADB 需求得到用户确认。

参考标记：lineage-standard-ota-validated、generated-recovery-validated。标准 OTA 与源码 recovery 的验收分别记录在 [37](37-standard-build-targets.md)、[38](38-generated-recovery.md)。

## 后续阶段

| 顺序 | 工作 | 完成条件 |
| --- | --- | --- |
| 1 | 固定构建输入，补齐可复现说明 | 新工作目录按文档准备源码、blob 和必要补丁，能构建对应功能的产物；明确版本及允许变化的时间戳/签名盐等信息 |
| 2 | 梳理 GSI 兼容项和设备配置 | 每个保留项都有本机用途依据；逐步收敛通用 GSI 设置，显示、音频、按键、电源等需要的设备配置可定位 |
| 3 | 将 vendor 迁移到常规 prebuilt 模块 | 标准模块/复制规则生成 vendor；必要权限、标签、链接保持，能替代自定义镜像生成器及 vendor 相关构建补丁 |
| 4 | 整理 SELinux/VINTF | 运行日志、实际服务、设备声明和策略规则相互对应，必要权限明确，保持 VINTF 检查通过 |
| 5 | 补充使用边界记录、完成维护交接 | 未覆盖的日常场景按实际硬件及使用需求补充，构建/发布/问题定位说明足够后续维护 |

阶段 3 按用户意见暂不急于开始。阶段可以拆开执行，但不一次替换全部兼容层。

### 1. 可复现构建

- [ ] 记录 Lineage 源码、设备树、构建补丁和原厂固件的版本/提交及来源。
- [ ] 为保留的 blob 建立校验记录，明确提取工具输入、生成文件和维护文件的区别。
- [ ] 说明 setup-makefiles.sh 的补丁应用逻辑及新环境的工具依赖。
- [ ] 在独立输出目录或新工作目录做一次构建复现；不要求因文档整理重复刷机。

现有入口：extract-files.sh、setup-makefiles.sh、vendor-config、patches、proprietary-files.txt。

### 2. GSI 兼容项与设备适配

- [ ] 审计 lineage_S17Promini.mk 对 gsi_release.mk 的继承：skip_mount、GSI init、VNDK、APEX 布局等逐项记录用途。
- [ ] 优先拆分已确认需要的配置；移除某项前先确认原厂 ramdisk/vendor 的依赖，不以“不是常规 DT”作为删除理由。
- [ ] 梳理现有 GLES fallback、USB init、density 和 vendor 提供的显示/音频/电源配置。
- [ ] 仅为本机确有需要的功能添加 device overlay/属性；例如亮度曲线、功能开关、按键和电池统计配置。
- [ ] 调试 ADB 继续遵循用户需求，明确其 userdebug/eng 生效范围。

验收：基本功能保持正常，配置能追溯到具体硬件或运行需求，减少没有依据的通用默认项。

### 3. 标准 vendor 模块（暂缓）

- [ ] 分类库、HAL、可执行程序、APK overlay、固件和配置文件，区分源码模块与需要保留的 blob。
- [ ] 逐步生成 Android.bp/Android.mk prebuilt 模块和标准 PRODUCT_COPY_FILES；保留真实 32/64 位路径、链接及原签名。
- [ ] 用现有 vendor-config 元数据作为对照，只保留实际需要的权限/标签/capability 例外。
- [ ] 分批验证后切换原生 vendorimage 构建，撤去自定义 ext4 生成规则及相应 target-files 补丁。
- [ ] 重新核对标准 target-files、block map、VINTF 和安装脚本的软件产物。

验收：新 vendor 的文件内容及必要元数据有对照依据，硬件功能保持正常；原始完整元数据记录可保留为参考，不必永远作为构建输入。

### 4. SELinux / VINTF

- [ ] 收集需要调查的 AVC 和服务错误，结合实际故障处理，避免仅按日志批量放行。
- [ ] 核对原厂 CIL/mapping 的版本和依赖，评估能明确维护的设备专用规则。
- [ ] 将 compatibility_matrix.xml 与实际 vendor manifest/服务对应，保留有依据的 optional HAL 声明。
- [ ] 明确普通系统与调试 recovery 的策略差异，不用全局模式字符串单独判断策略是否正确。

验收：需要的服务正常、策略理由可解释、VINTF 通过；不因当前内核缺源码而强求全部策略/驱动源码化。

### 5. 使用边界与交接

- [ ] 只补未明确覆盖的项目；RIL 若已含通话/短信/移动数据则直接记录通过，未覆盖才补。
- [ ] 按需要记录长时间待机、唤醒、蓝牙音频切换、相机连续使用、充电温度等场景。
- [ ] 根据真实硬件选择定位/传感器/USB OTG 等项目，不给不存在的硬件建立任务。
- [ ] 整理已知限制、构建命令、产物校验、问题日志抓取与维护说明。

## 保留方案与暂缓事项

- prebuilt kernel 和闭源 HAL 本身不阻碍成熟化，原厂组件必须配套，不强求无源码内核重写。
- stock first-stage ramdisk、融合 product/system_ext 可以继续保留；若以后修改，只处理有明确收益的部分。
- recovery 触摸已由 OSS 内核修复，2026-10-11 用户确认；见 [修复记录](95-recovery-touch-fixed.md)。
- Android 升级、增量 OTA、自动更新服务、公开发布及发布密钥切换不在本轮范围，另行确定需求。

## 推进方式

每次只推进一个可核对的改动，记录目的、变更、验证及结果。保留已验证基线；只重测被改动影响的部分，不重复已完成的安装路径验收。后续完成某项时更新本文件勾选状态并关联对应提交/文档。
