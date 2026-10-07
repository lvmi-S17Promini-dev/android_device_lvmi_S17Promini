# 补齐拨号应用

现象：系统可读取 IMEI，但桌面没有电话应用。

原因：common.mk 继承 full_base.mk；Lineage common_full_phone.mk 只补充 messaging/Stk 等，没有继承 AOSP telephony_product.mk 中的 Dialer。已有构建产物包含 Telecom、TeleService，vendor 也声明 GSM/IMS 功能，但没有 Dialer.apk。

修复：在 ROM 产品 lineage_S17Promini.mk 中加入 PRODUCT_PACKAGES += Dialer。其依赖自动带入拨号应用权限白名单；沿用现有厂商 RIL，不额外引入 AOSP rild。

验证：soong_ui --dumpvar-mode PRODUCT_PACKAGES 解析成功，最终产品包列表包含 Dialer；本轮未重编完整 ROM。

重新构建安装包并刷入后，检查电话应用、拨出/接听及通话音频。IMEI 可读不等同于这些功能已经验证。此项实机验证待完成。
