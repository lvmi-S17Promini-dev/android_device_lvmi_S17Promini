# 独立 recovery 分区实机测试

前提已由用户确认：bootloader unlocked=yes、secure=no；`fastboot reboot recovery` 可以直接进入原厂 recovery；关机后同时按住音量 +/− 插 USB 可进入 BROM 并用 mtkclient 读取。原厂回写实际操作尚未验证。

## Windows 操作

使用新构建的 `artifacts/recovery-384.img`，先复制到 Windows 当前目录；保留原厂 `stock_imgs/recovery.bin` 和既有 mtkclient 环境用于回退。

```powershell
adb reboot bootloader
fastboot flash recovery .\recovery-384.img
# 只有 Sending 和 Writing 都成功才执行下一条。
fastboot reboot recovery
adb devices -l
adb shell id
```

不要先运行普通 `fastboot reboot` 进入 Android；原厂 vendor install-recovery.sh 可能将自编 recovery 覆盖回原厂。遇到 FAILED 保留完整输出，先排查，不顺带改 vbmeta、boot、LK 或 super。测试中不执行恢复出厂、格式化或安装 zip。

## 取证

记录显示是否正常、是否进入 Lineage recovery、按键是否可选菜单、ADB 是否连接、id 是否 uid=0。

```powershell
adb shell getenforce
adb shell getprop sys.usb.controller
adb shell getprop sys.usb.state
adb pull /tmp/recovery.log .\recovery.log
adb shell dmesg > recovery-dmesg.txt
```

黑屏也先检查 adb devices，能连接时先取日志。只出现 sideload 状态不能当作已有 root adb shell。

## 原厂回退（仅失败后使用）

若仍可进入 bootloader fastboot，将原厂备份复制为 Windows 当前目录 recovery-stock.bin：

```powershell
fastboot flash recovery .\recovery-stock.bin
fastboot reboot recovery
```

若无法进入 fastboot，用已确认的关机按音量 +/− 插 USB 方法进入 BROM，在之前成功的 mtkclient 环境回写原厂 recovery；Linux 工作目录命令如下，Windows 使用相应本地路径：

```bash
cd ~/mtkclient
python mtk.py w recovery /home/dengxh/S17Promini_LineageOS/stock_imgs/recovery.bin
```

仅回写 recovery，不恢复所有分区或改写 GPT/preloader/LK。卡死时需先通过机型实际支持的强制复位办法回到可接入 BROM 的状态。

本页为待执行流程；主机没有连接实机，不代表已刷写或启动自编 recovery。

## 当前候选镜像

构建和静态检查通过：recovery-384.img，20840448 bytes，小于 32MiB 分区容量。
SHA256：`8845c801b93b0f5f795d37f761f95f2a5c0b5a702957a209612576c7ec773004`。Windows 可用 `Get-FileHash .\recovery-384.img -Algorithm SHA256` 核对。

## 用户实测结果

自编 recovery 已启动，显示正常。root ADB、分区访问和 fastbootd 尚未收到验证结果；上述回退命令仍是备用流程。
