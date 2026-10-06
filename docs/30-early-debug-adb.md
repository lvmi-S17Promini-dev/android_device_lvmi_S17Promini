# 调试系统尽早开启免授权 ADB（2026-10-06）

按用户要求，当前 system-only 的 userdebug/eng 产品在继承 Lineage 配置前设置 WITH_ADB_INSECURE=true，由 Lineage 原有逻辑生成 ro.adb.secure=0；不添加同名重复属性。普通 user 目标不主动设置这个开关。原厂 boot/vendor 在其他分区的旧默认 USB 配置不会阻止 init 根据 ro.adb.secure=0 选择 adb。

init.s17promini-rom.rc 在 init 配置 configfs/controller；post-fs（stock vendor 已创建 gadget/FunctionFS）设置 MTK USB controller、ACM/PID 属性，并设置 sys.usb.config=adb、start adbd。加载持久属性后再次设置 persist.sys.usb.config=adb 及当前 USB 配置，避免旧 USB-off 值覆盖本轮调试默认。后续运行时仍使用现有 USB 配置切换流程。

Android 12 的原 adbd 服务为 updatable，post-fs 的启动请求要等 APEX 完成激活才能执行，不能保证在 /data 挂载失败之前可用。此改动目标是尽早在正常 init/APEX 流程中提供 USB ADB，无需进入桌面或确认授权；第一阶段/SELinux 策略加载之前失败仍使用现有 boot collector。

验证：lunch 后 PRODUCT_SYSTEM_DEFAULT_PROPERTIES 中 ro.adb.secure=0；host_init_verifier 使用 platform/vendor property contexts 校验 RC 通过。未构建新镜像，实机枚举时机和免授权连接尚待验证。现有 recovery 的免授权配置不变，未新增 TCP ADB，也未改变 ro.secure 或强制 adbd root。

构建及生效：本轮 ADB 配置随 system.img 更新，无需等待 vendor 接线；执行原构建命令 m -j8 systemimage vbmetaimage，并在 fastbootd 刷入新的 system.img。recovery 恢复组件删除则要等后续新 vendor 镜像刷入才生效。

实机验证：冷启动时运行 adb wait-for-device，连接后查看 getprop ro.adb.secure、getprop sys.usb.config、getprop init.svc.adbd，应分别是 0、包含 adb、running；用尚未在此机授权的主机/临时 ADB key 验证无需确认（既有授权主机单独连接成功不能证明免授权）。
