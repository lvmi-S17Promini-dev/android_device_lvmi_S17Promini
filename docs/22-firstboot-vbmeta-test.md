# 首次启动：空 vbmeta 对照（2026-10-06）

用户确认 patched LK 在刷 system/vbmeta 前能正常启动原厂系统，且 r5 Format data 后能完成原厂恢复出厂启动。当前优先检查替换镜像组合，不改 LK。
已构建 system 展开大小2105655296，小于stock3063197696，VNDK31、skip_mount和GLES init已在输出中。Windows vbmeta头已确认AVB0。
当前 LK日志只记录选择fastboot，pstore与旧r3记录相同；没有本次失败的直接错误依据，不能据此定位唯一原因。

编译生成的vbmeta含system链和RSA4096签名。新增最小对照文件，Algorithm=NONE、flags=3、无链、4096字节：

```bash
python3 external/avb/avbtool.py make_vbmeta_image --flags 3 --padding_size 4096 --output /home/dengxh/S17Promini_LineageOS/artifacts/rom-firstboot/vbmeta-disabled.img
```

SHA256 3e679bb0b8b2e6fb5d94d8316846b7459eead2209cee8f038cbbdda8c6483750。
只替换vbmeta，system保持本次构建版本；不重编译、不再次清data。

```powershell
fastboot flash vbmeta .\vbmeta-disabled.img
fastboot reboot
```

此为AVB配置对照试验，不声称已确认根因或启动成功。用户已授权清data且重要数据已备份，已有Format data成功记录；本轮不执行擦除。
