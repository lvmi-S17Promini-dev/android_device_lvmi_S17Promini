# 安装 zip r3：修正 range_sha1 参数编码（2026-10-06）

证据：lineage-debug/zip-r2-recovery.log 显示 system block update 完成，wrote 484941 blocks; expected 484941，随后 Invalid range text: 0-474722 491520-491538 ...，Check failed: static_cast<bool>(rs)，updater 被 signal 6 中止。本次实际 abort 位于 RangeSha1Fn。

根因：安装脚本将 Python RangeSet.to_string() 的人类可读格式传给 native range_sha1。C++ RangeSet::Parse 要求 endpoint_count,start,end,... 逗号格式；解析失败后 CHECK 触发 SIGABRT。

修复：system/vendor 两处统一使用 to_string_raw()，同时在生成脚本时用 RangeSet.parse_raw 回读并核对原 care_map。SHA 校验保留，镜像、LP 操作、transfer.list 和数据内容保持原样。

r3 保存到 artifacts/rom-install-r3/lineage-19.1-S17Promini-r3.zip；r2 停用。用户应留在 recovery 重试，不清 data。r2 中 system 已完成写入阶段，但尚未完成 SHA 校验和后续 vendor/boot/vbmeta/recovery 写入；不能据此认为整包已安装完成。

日志归档在工作目录 lineage-debug，UTF-16 dmesg 已转换到 normalized；生成日志不提交 Git。

验证：m s17-installzip 成功；r3 两处 CSV 参数满足 native parser 的计数/边界要求，并与 r2 的原 care_map 范围逐项一致，预期 SHA1 未变；镜像输入、LP 操作和 transfer.list 与 r2 一致。整体 CMS 签名校验通过。SHA256 2264bb9065710c1fc33311488785afe727e3f9dc64b819e67451c0952c6de0ff。待实机重试。
