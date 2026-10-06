# 安装 zip r2：保护未挂载目录的卸载操作（2026-10-06）

用户确认正常 boot 启动成功；首测安装 zip 报 Failed to unmount /system_root: No such volume。

根因：19.1 updater 的 UnmountFn 在路径未挂载时 UiPrint 后返回 nullptr，Edify 将其视为执行失败；即使未用 assert 包裹也会中止脚本。r1 的三个裸 unmount 调用因此错误，/system_root 是第一个。

修复：/system_root、/system、/vendor 均改为 ifelse(is_mounted(path), unmount(path), "")，仅在实际挂载时卸载。IsMountedFn 未挂载时返回空字符串；IfElseFn 惰性执行所选分支，避免触发 UnmountFn 的 nullptr 路径。

该失败发生在 update_dynamic_partitions 之前，尚未执行 LP resize 或镜像写入。原有 system/vendor/product/boot/vbmeta 不因该脚本报错改变；正常 boot 的独立实测结果仍有效。

重建 m s17-installzip，新的包保存到 artifacts/rom-install-r2/lineage-19.1-S17Promini-r2.zip。r1 停用；本轮修复不需要清 data，回 recovery 菜单重新选择 Apply update → Apply from ADB 后 sideload r2。后续 LP 与 block update 仍待实机继续验证。

验证：m s17-installzip 成功；r2 包内三处 guard 存在，镜像输入 SHA256、LP 操作、transfer.list 与 r1 一致；整体 CMS 签名校验通过。SHA256 456ae3b6a281dcefeb27bef08ad10177ad46535cbdbcc2fd3b09b3e8b23cc5ac。实机修复效果待重试。
