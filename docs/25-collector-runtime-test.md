# Cache采集器没有生成文件：先测试程序（2026-10-06）

用户已成功写入boot-kmsg-debug并尝试continue，回r5后/cache为空。没有日志不能证明内核未启动；collector原先在设备/挂载准备失败时直接退出，可能是等待条件、挂载、权限或启动阶段问题。
新增独立--test模式（不exec原init），输出准备和挂载错误；在现有r5用root测试ARM32程序可执行性、cache设备和日志写入。写独立s17-collector-test.log，不覆盖失败启动日志。

```powershell
adb push .\boot-kmsg-collector-test /tmp/s17-collector
adb shell chmod 755 /tmp/s17-collector
adb shell /tmp/s17-collector --test
adb pull /cache/s17-collector-test.log .\collector-test.log
```

独立工具已静态编译，无需刷写。当前debug boot镜像未重新制作；程序测试通过也不等于boot早期的同一逻辑一定成功，后续再核对mount namespace/时序。boot/recovery/kernel/vbmeta本轮不改写。

实测补充：test 和早期启动日志均已保存到缓存分区。之前空目录是 /cache 未挂载，以及 shell 在挂载前已进入该目录；挂载后使用绝对路径或重新进入即可看到日志。启动失败原因见 [genfscon 冲突](26-firstboot-genfscon.md)。
