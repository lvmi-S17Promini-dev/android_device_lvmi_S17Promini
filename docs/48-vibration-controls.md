# 振动分类控制入口

“设置 → 声音”添加“振动和触感强度”入口，复用 Android 12 已有的
`com.android.settings.accessibility.VibrationSettings` 页面。
该设备实际提供来电、通知、触摸反馈的分类开/关，不显示强度档位。

实现文件：`overlay/packages/apps/Settings/res/xml/sound_settings.xml`。
Android 资源覆盖需要完整的声音页面 XML，其余原有设置条目保持一致。

关闭范围：

- 通知开关关闭通知用途振动。
- 触摸反馈开关供系统和遵循该设置的应用使用。
- 来电开关关闭响铃时振动；手机处于“振动”铃声模式时仍可能振动。
- 应用主动调用 vibrator、闹钟等不受这三个分类开关统一控制。

原厂 HAL 不支持调幅，当前没有已确认的驱动调幅接口，因此此入口仅提供分类开关。

构建：`m -j8 Settings`；需要重新打包并更新 system 才能使用新增入口。

验证：`m -j8 services Settings` 构建通过，APK 已确认包含分类控制入口，
XML 对照检查确认原声音设置条目完整保留。用户确认实机测试通过。
