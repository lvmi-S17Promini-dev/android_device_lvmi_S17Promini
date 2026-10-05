# SELinux 非常规放宽方式：全局状态与 domain permissive

用户允许移植调试时关闭 Enforcing，问预编译内核能否采用其他方式。原厂全局切换限制仍成立，但需要补充：**全局切换与策略域 permissive 是两条不同机制**。

## 已核对的依据

- Linux 4.19 上游 include/security.h：CONFIG_SECURITY_SELINUX_DEVELOP=n 时 enforcing_enabled 返回 true，enforcing_set 不修改状态。
- 上游 ss/services.c：policydb.permissive_map 的 source type 会给 av_decision 设置 AVD_FLAGS_PERMISSIVE，无 DEVELOP 条件包围。
- 上游 avc.c 的 avc_denied：全局 enforcing 且没有 domain permissive 才拒绝普通 AVC 检查；AVC_STRICT 等路径仍有单独检查。
- 当前 r3 compiled recovery policy 经 sepolicy-analyze permissive 枚举，已包含 recovery、su、backuptool。用户看到 getenforce=Enforcing 与这些域 permissive 并不冲突。

来源：
- https://github.com/torvalds/linux/blob/v4.19/security/selinux/include/security.h
- https://github.com/torvalds/linux/blob/v4.19/security/selinux/ss/services.c
- https://github.com/torvalds/linux/blob/v4.19/security/selinux/avc.c

厂商没有提供本机完整源码；上游机制不能代替本机新增域 permissive 的实机验证。当前已有 permissive domains 证明策略构建支持此机制，但没有直接捕获本机某次 domain permissive 绕过拒绝的对照实验。

## 可用的调试路线

1. 优先修具体标签/allow（r3 super 修复）。能保留 AVC 对问题定位的作用。
2. 如需隔离 fastbootd 的权限问题，可在仅 recovery/userdebug 调试构建加入 `permissive fastbootd;`，必要时 charger 同理。**getenforce 仍可显示 Enforcing**，但这些域的普通 AVC 拒绝可不再阻止操作。r3 未加入 fastbootd/charger permissive；本轮未改变策略。
3. 可用 magiskpolicy 对当前策略或离线策略加入某个域 permissive，不必为了 recovery root shell 先安装完整 Magisk。

仅说明工具语法，当前镜像没有 magiskpolicy 可执行文件，本轮没有在设备执行：

```bash
magiskpolicy --live 'permissive fastbootd'
```

官方工具文档：https://topjohnwu.github.io/Magisk/tools.html#magiskpolicy 。该工具修改策略而非把内核的 CONFIG_DEVELOP 变成 y；安装 Magisk 本身不保证全局 setenforce 可用。全部实际域逐一 permissive 会很广泛地绕开策略拒绝，但也不等价于恢复内核全局开关，不能仅用 getenforce 作为验收。
4. 若一定要让内核真正关闭全局 enforcing，需重编译适配的内核，或反汇编 stock Image 做针对本机版本的补丁（AVC/相关执行路径），再 gzip/repack。没有源码时后者可能可研究，但尚无本机验证补丁。改变 config 文本或仅伪造 getenforce 输出不改变真实执行行为。

当前已经能用原厂 kernel 启动 recovery 和 root ADB，优先不引入未知内核补丁。r3 仍等待用户验证 logical system 查询，不能把查不到分区直接视为必须全局关闭 SELinux。
